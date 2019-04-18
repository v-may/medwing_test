class ThermostatsController < BaseController
  before_action :load_thermostat
  before_action :authenticate_thermostat

  def stats
    render_serialized do
      fields = %w(temperature humidity battery_charge)
      functions = %w(min max avg)
      result_fields = %w(id)

      field_list = 'thermostat_id as id,'
      field_list += fields.map do |field|
        functions.map do |function|
          result_field = "#{function}_#{field}"
          result_fields << result_field
          "#{function}(#{field}) as #{result_field}"
        end
      end.flatten.join(',')

      @thermostat.readings.select(field_list).first.to_json only: result_fields
    end
  end

  private

  def load_thermostat
    @thermostat = Thermostat.find params[:id]
  end
end