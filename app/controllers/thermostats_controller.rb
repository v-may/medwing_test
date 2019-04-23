class ThermostatsController < BaseController
  before_action :load_thermostat
  before_action :authenticate_thermostat

  def stats
    res = ThermostatStats.call @thermostat

    if res.success?
      render_serialized { res.data.to_json }
    else
      render_error res.errors.map(&:message).join(', ')
    end
  end

  private

  def load_thermostat
    @thermostat = Thermostat.find params[:id]
  end
end