require 'rails_helper'

RSpec.describe Reading, type: :model do
  let(:thermostat) { create :thermostat }
  let(:reading) { build :reading, thermostat: thermostat }

  it { should belong_to(:thermostat) }

  describe '::create_later!' do
    let!(:cached_reading) { Reading.create_later! reading.attributes }

    it 'schedules the reading creation and stores the data in the cache' do
      expect(Reading.method :create!).to be_delayed(cached_reading.attributes.symbolize_keys)
      expect(REDIS.get "#{Rails.env}_reading_#{cached_reading.id}").
        to eq cached_reading.attributes.symbolize_keys.to_json
      expect { Sidekiq::Worker.drain_all }.to change { Reading.count }.by 1
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
