class ThermostatStats
  include Callable

  attr_reader :data, :errors, :thermostat

  def initialize(thermostat)
    @errors = []
    @thermostat = thermostat
  end

  def success?
    errors.none?
  end

  def call
    begin
      @data = thermostat.readings.select(field_list).first
      process_pending_readings
      format_data
    rescue Exception => e
      errors << e
      @data = nil
    end
    self
  end

  private

  def fields
    %w(temperature humidity battery_charge)
  end

  def functions
    %w(min max sum)
  end

  def field_list
    field_list = 'thermostat_id as id,count(*) as row_count, max(id) as last_id,'
    field_list += fields.map do |field|
      functions.map do |function|
        result_field = "#{function}_#{field}"
        "#{function}(#{field}) as #{result_field}"
      end
    end.flatten.join(',')
  end

  def process_pending_readings
    (@data["last_id"].next..Reading.last_id).each do |pending_reading_id|
      begin
        reading = Reading.find pending_reading_id
      rescue ActiveRecord::RecordNotFound
        next
      end

      next unless reading.thermostat_id == thermostat.id

      @data['row_count'] += 1
      fields.each do |field|
        value = reading.send(field)
        parameter = "min_#{field}"
        @data[parameter] = value if value < @data[parameter]
        parameter = "max_#{field}"
        @data[parameter] = value if value > @data[parameter]
        @data["sum_#{field}"] += value
      end
    end
  end

  def format_data
    result_data = { 'id' => @data['id']}
    fields.each do |field|
      functions.first(2).each do |function|
        parameter = "#{function}_#{field}"
        result_data[parameter] = @data[parameter]
      end

      parameter = "avg_#{field}"
      result_data[parameter] = @data["sum_#{field}"] / @data['row_count']
    end
    @data = result_data
  end
end