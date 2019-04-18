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
    let(:request_path) { stats_thermostat_path thermostat }

    before { get request_path }

    specify { expect(response).to have_http_status :unauthorized }

    context 'with a token parameter' do
      let(:request_path) { stats_thermostat_path thermostat, token: thermostat.household_token }

      it 'returns the reading data' do
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
        let(:request_path) { "/thermostats/999999/stats?token=#{thermostat.household_token}" }

        specify { expect(response).to have_http_status :not_found }
      end
    end

    context 'given a token in the request header' do
      before { get request_path, headers: { 'X-Token' => thermostat.household_token } }

      specify { expect(response).to have_http_status :ok }
    end

    context 'with wrong token' do
      let(:another_household_s_thermostat) { create :thermostat, household_token: 'other-token'}
      let(:request_path) { stats_thermostat_path thermostat, token: another_household_s_thermostat.household_token }

      specify { expect(response).to have_http_status :unauthorized }
    end
  end
end