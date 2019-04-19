class ReadingsController < BaseController
  before_action :load_data
  before_action :authenticate_thermostat

  def create
    @reading = Reading.create_later! readings_params.merge(thermostat_id: @thermostat.id)

    render_serialized(201) do
      @reading
    end
  end

  def show
    render_serialized do
      Reading.find(params[:id])
    end
  end

  private

  def load_data
    if params[:id]
      @reading = Reading.find params[:id]
      @thermostat = @reading.thermostat
    else
      @thermostat = Thermostat.find params[:thermostat_id]
    end
  end

  def readings_params
    params.permit(:temperature, :humidity, :battery_charge)
  end
end