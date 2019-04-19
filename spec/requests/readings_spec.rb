require 'rails_helper'

RSpec.describe 'Readings API', type: :request do
  let(:reading) { create :reading }
  let(:thermostat) { reading.thermostat }

  describe 'GET /readings/:id' do
    let(:request_path) { reading_path reading }

    before { get request_path }

    specify { expect(response).to have_http_status :unauthorized }

    context 'with a token parameter' do
      let(:request_path) { reading_path reading, token: thermostat.household_token }

      it 'returns the reading data' do
        expect(response).to have_http_status :ok
        check_reading reading.attributes.symbolize_keys
      end

      context 'given wrong id' do
        let(:request_path) { "/readings/999999?token=#{thermostat.household_token}" }

        specify { expect(response).to have_http_status :not_found }
      end
    end

    context 'given a token in the request header' do
      before { get request_path, headers: { 'X-Token' => thermostat.household_token } }

      specify { expect(response).to have_http_status :ok }
    end

    context 'with wrong token' do
      let(:another_household_s_thermostat) { create :thermostat, household_token: 'other-token'}
      let(:request_path) { reading_path reading, token: another_household_s_thermostat.household_token }

      specify { expect(response).to have_http_status :unauthorized }
    end
  end

  describe 'POST /:thermostat_id/readings' do
    let(:thermostat) { create :thermostat }
    let(:request_path) { thermostat_readings_path thermostat }
    let(:params) { { humidity: 41.6, temperature: 22.7, battery_charge: 78.9 } }

    before do
      Reading.reset_redis
      post request_path,
        params: params.to_json,
        headers: { 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json' }
    end

    specify { expect(response).to have_http_status :unauthorized }

    context 'with a token parameter' do
      let(:request_path) { thermostat_readings_path thermostat, token: thermostat.household_token }

      it 'returns the reading data and schedules its creation' do
        reading_attrs = { id: 1, thermostat_id: thermostat.id }.merge(params)

        expect(response).to have_http_status :created
        check_reading reading_attrs
        expect(Reading.method :create!).to be_delayed(reading_attrs)

        Sidekiq::Worker.drain_all

        check_reading Reading.last.attributes.symbolize_keys
      end

      context 'given a wrong thermostat id' do
        let(:request_path) { "/thermostats/999999/readings?token=#{thermostat.household_token}" }

        specify { expect(response).to have_http_status :not_found }
      end
    end

    context 'given a token in the request header' do
      before do
        post request_path,
          params: params.to_json,
          headers: {
            'CONTENT_TYPE' => 'application/json',
            'ACCEPT' => 'application/json',
            'X-Token' => thermostat.household_token
          }
      end

      specify { expect(response).to have_http_status :created }
    end

    context 'with wrong token' do
      let(:another_household_s_thermostat) { create :thermostat, household_token: 'other-token'}
      let(:request_path) { thermostat_readings_path thermostat, token: another_household_s_thermostat.household_token }

      specify { expect(response).to have_http_status :unauthorized }
    end
  end

  def check_reading(params={})
    json = JSON.parse(response.body)

    expect(json['id']).to eq params[:id]
    expect(json['thermostat_id']).to eq params[:thermostat_id]
    expect(json['number']).to eq params[:number]
    expect(json['temperature']).to eq params[:temperature]
    expect(json['humidity']).to eq params[:humidity]
    expect(json['battery_charge']).to eq params[:battery_charge]
  end
end