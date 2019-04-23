require 'rails_helper'

RSpec.describe ThermostatStats, type: :model do
  let(:thermostat) do
    create(:thermostat).tap do |t|
      t.readings.create!(temperature: 40.44, humidity: 30.88, battery_charge: 75)
      t.readings.create!(temperature: 0, humidity: 55, battery_charge: 5.25)
      t.readings.create!(temperature: -20.5, humidity: 0, battery_charge: 100)
    end
  end
  let!(:other_thermostat) do
    create(:thermostat).tap do |t|
      t.readings.create!(temperature: -273, humidity: 13.13, battery_charge: 66.6)
    end
  end

  subject { ThermostatStats.call thermostat }

  it 'returns the readings stats' do
    expect(subject).to be_success

    data = subject.data

    expect(data['id']).to eq thermostat.id
    expect(data['max_temperature']).to eq 40.44
    expect(data['min_temperature']).to eq -20.5
    expect(data['avg_temperature'].round(2)).to eq 6.65
    expect(data['max_humidity']).to eq 55
    expect(data['min_humidity']).to eq 0
    expect(data['avg_humidity'].round(2)).to eq 28.63
    expect(data['max_battery_charge']).to eq 100
    expect(data['min_battery_charge']).to eq 5.25
    expect(data['avg_battery_charge'].round(2)).to eq 60.08
  end

  context 'with errors' do
    before { allow(thermostat).to receive(:readings).and_raise('Something went wrong') }

    it 'returns errors data' do
      expect(subject).not_to be_success
      expect(subject.errors.map(&:message)).to eq ['Something went wrong']
    end
  end

  context 'given pending readings' do
    before do
      Reading.create_later!(thermostat_id: thermostat.id, temperature: 45, humidity: 66, battery_charge: 45)
      Reading.create_later!(thermostat_id: other_thermostat.id, temperature: 100, humidity: 100, battery_charge: 0.07)
      Reading.create_later!(thermostat_id: thermostat.id, temperature: -50, humidity: 5, battery_charge: 2)
    end

    it 'includes pending readings' do
      expect(subject).to be_success

      data = subject.data

      expect(data['id']).to eq thermostat.id
      expect(data['max_temperature']).to eq 45
      expect(data['min_temperature']).to eq -50
      expect(data['avg_temperature'].round(2)).to eq 2.99
      expect(data['max_humidity']).to eq 66
      expect(data['min_humidity']).to eq 0
      expect(data['avg_humidity'].round(2)).to eq 31.38
      expect(data['max_battery_charge']).to eq 100
      expect(data['min_battery_charge']).to eq 2
      expect(data['avg_battery_charge'].round(2)).to eq 45.45
    end
  end
end
