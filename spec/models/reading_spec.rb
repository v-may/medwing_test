require 'rails_helper'

RSpec.describe Reading, type: :model do
  let(:thermostat) { create :thermostat }
  let(:reading) { build :reading, thermostat: thermostat }

  it { should belong_to(:thermostat) }

  before { Reading.reset_redis }

  describe '::create_later!' do
    let!(:cached_reading) { Reading.create_later! reading.attributes }

    it 'schedules the reading creation and stores the data in the cache' do
      expect(Reading.method :create!).to be_delayed(cached_reading.attributes.symbolize_keys)

      cached_data = JSON.parse REDIS.get("#{Rails.env}_reading_#{cached_reading.id}")

      expect(cached_data).to eq cached_reading.attributes
      expect(cached_data["id"]).to eq 1
      expect(cached_data["number"]).to eq 1

      expect { Sidekiq::Worker.drain_all }.to change { Reading.count }.by 1
    end

    it 'increments sequences in Redis cache' do
      (2..3).each do |i|
        reading = Reading.create_later! thermostat: thermostat

        expect(reading.id).to eq i
        expect(reading.id).to eq Reading.last_id
        expect(reading.number).to eq i
        expect(reading.number).to eq Reading.last_number(thermostat)
      end
    end

    context 'given persisted reading' do
      before { Reading.create thermostat: thermostat }

      it 'takes next value' do
        reading = Reading.create_later! thermostat: thermostat

        expect(reading.id).to eq 3
        expect(reading.number).to eq 3
      end
    end

    context 'given several thermostats' do
      let(:other_thermostat) { create :thermostat, household_token: 'other-token' }
      let(:same_household_thermostat) { create :thermostat, household_token: thermostat.household_token }

      it 'increments the number sequence in context of household' do
        reading = Reading.create_later! thermostat: thermostat
        other_reading = Reading.create_later! thermostat: other_thermostat
        same_household_reading = Reading.create_later! thermostat: same_household_thermostat

        expect(reading.number).to eq 2
        expect(same_household_reading.number).to eq 3
        expect(other_reading.number).to eq 1
      end

      context 'given persisted reading' do
        before do
          Reading.create thermostat: thermostat
          Reading.create thermostat: other_thermostat
        end

        it 'takes next value' do
          reading = Reading.create_later! thermostat: thermostat
          other_reading = Reading.create_later! thermostat: other_thermostat
          same_household_reading = Reading.create_later! thermostat: same_household_thermostat

          expect(reading.number).to eq 3
          expect(same_household_reading.number).to eq 4
          expect(other_reading.number).to eq 2
        end
      end
    end

    context 'after create' do
      before { Sidekiq::Worker.drain_all }

      it 'removes the cached data from Redis' do
        expect(REDIS.get "#{Rails.env}_reading_#{cached_reading.id}").not_to be
      end
    end
  end

  describe '::create' do
    it 'increments sequences in Redis cache' do
      (1..2).each do |i|
        reading = Reading.create thermostat: thermostat

        expect(reading.id).to eq i
        expect(reading.id).to eq Reading.last_id
        expect(reading.number).to eq i
        expect(reading.number).to eq Reading.last_number(thermostat)
      end
    end

    context 'given pending reading' do
      before { Reading.create_later! thermostat: thermostat }

      it 'takes next value' do
        reading = Reading.create thermostat: thermostat

        expect(reading.id).to eq 2
        expect(reading.number).to eq 2
      end
    end

    context 'given several thermostats' do
      let(:other_thermostat) { create :thermostat, household_token: 'other-token' }
      let(:same_household_thermostat) { create :thermostat, household_token: thermostat.household_token }

      it 'increments the number sequence in context of household' do
        reading = Reading.create thermostat: thermostat
        other_reading = Reading.create thermostat: other_thermostat
        same_household_reading = Reading.create thermostat: same_household_thermostat

        expect(reading.number).to eq 1
        expect(same_household_reading.number).to eq 2
        expect(other_reading.number).to eq 1
      end

      context 'given pending reading' do
        before do
          Reading.create_later! thermostat: thermostat
          Reading.create_later! thermostat: other_thermostat
        end

        it 'takes next value' do
          reading = Reading.create thermostat: thermostat
          other_reading = Reading.create thermostat: other_thermostat
          same_household_reading = Reading.create thermostat: same_household_thermostat

          expect(reading.number).to eq 2
          expect(same_household_reading.number).to eq 3
          expect(other_reading.number).to eq 2
        end
      end
    end
  end

  describe '::find' do
    it 'loads data from database' do
      reading.save!

      expect(Reading.find reading.id).to eq reading
    end

    context 'given not persisted data' do
      let!(:cached_reading) { Reading.create_later! reading.attributes }

      it 'fetches data from the cache' do
        expect(Reading.find cached_reading.id).to eq cached_reading
      end
    end

    context 'given wrong id' do
      specify do
        expect { Reading.find -1 }.to raise_error ActiveRecord::RecordNotFound
      end
    end
  end
end
