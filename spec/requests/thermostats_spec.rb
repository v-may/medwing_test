require 'rails_helper'

RSpec.describe 'Thermostats API', type: :request do
  describe 'GET /thermostats/:id/stats' do
    let(:thermostat) do
      create(:thermostat).tap do |thermostat|
        thermostat.readings.create!(temperature: 40.44, humidity: 30.88, battery_charge: 75)
        thermostat.readings.create!(temperature: 0, humidity: 55, battery_charge: 5.25)
        thermostat.readings.create!(temperature: -20.5, humidity: 0, battery_charge: 100)
      end
    end

    it 'requires authorisation' do
      get stats_thermostat_path(thermostat)

      expect(response).to have_http_status :unauthorized
    end

    context 'with a token parameter' do
      it 'returns the reading stats' do
        expect(ThermostatStats).to receive(:call).with(thermostat).and_return(ThermostatStats.call thermostat)

        get stats_thermostat_path(thermostat, token: thermostat.household_token)

        expect(response).to have_http_status :ok

        json = JSON.parse(response.body)

        expect(json['id']).to eq thermostat.id
        expect(json['max_temperature']).to eq 40.44
        expect(json['min_temperature']).to eq -20.5
        expect(json['avg_temperature'].round(2)).to eq 6.65
        expect(json['max_humidity']).to eq 55
        expect(json['min_humidity']).to eq 0
        expect(json['avg_humidity'].round(2)).to eq 28.63
        expect(json['max_battery_charge']).to eq 100
        expect(json['min_battery_charge']).to eq 5.25
        expect(json['avg_battery_charge'].round(2)).to eq 60.08
      end

      context 'given wrong id' do
        specify do
          get "/thermostats/-1/stats?token=#{thermostat.household_token}"

          expect(response).to have_http_status :not_found
        end
      end

      context 'with errors' do
        before do
          allow(ThermostatStats).
            to receive(:call).with(thermostat).
            and_return(double 'thermostat stats', success?: false, errors: [Exception.new('Something went wrong')])
        end

        it 'returns errors data' do
          get stats_thermostat_path(thermostat, token: thermostat.household_token)

          expect(response).to have_http_status :unprocessable_entity

          json = JSON.parse(response.body)

          expect(json['error']).to eq 'Something went wrong'
        end
      end
    end

    context 'given a token in the request header' do
      specify do
        get stats_thermostat_path(thermostat), headers: { 'X-Token' => thermostat.household_token }

        expect(response).to have_http_status :ok
      end
    end

    context 'with wrong token' do
      let(:another_household_s_thermostat) { create :thermostat, household_token: 'other-token'}

      specify do
        get stats_thermostat_path(thermostat, token: another_household_s_thermostat.household_token)

        expect(response).to have_http_status :unauthorized
      end
    end
  end
end