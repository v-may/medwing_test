class Reading < ApplicationRecord
  belongs_to :thermostat

  before_create :set_defaults
  after_create :remove_from_redis

  CACHE_KEY_LAST_ID = "#{Rails.env}_reading_id"
  CACHE_KEY_DATA = "#{Rails.env}_reading_"
  CACHE_KEY_NUMBER = "#{Rails.env}_reading_number_"

  class << self
    def setup_redis
      REDIS.set CACHE_KEY_LAST_ID, Reading.maximum(:id).to_i, nx: true
    end

    def reset_redis
      REDIS.del CACHE_KEY_LAST_ID

      [CACHE_KEY_DATA, CACHE_KEY_NUMBER].each do |prefix|
        REDIS.keys(prefix + '*').each { |k| REDIS.del k }
      end

      setup_redis
    end

    def last_id
      REDIS.get(CACHE_KEY_LAST_ID).to_i
    end

    def next_id!
      REDIS.incr(CACHE_KEY_LAST_ID).to_i
    end

    def create_later!(options={})
      opts = options.to_h.symbolize_keys
      opts[:id] ||= next_id!
      opts[:number] ||= next_number!(opts[:thermostat_id] || opts[:thermostat].id)

      delay.create! opts

      REDIS.set (CACHE_KEY_DATA + opts[:id].to_s), opts.to_json

      new opts
    end

    def find(id)
      cached_value = REDIS.get(CACHE_KEY_DATA + id.to_s)
      if cached_value
        cached_opts = JSON.parse(cached_value)
        return new(cached_opts)
      end

      super
    end

    def next_number!(thermostat_or_id)
      thermostat = thermostat_or_id.is_a?(Thermostat) ? thermostat_or_id : Thermostat.find(thermostat_or_id)

      redis_key = CACHE_KEY_NUMBER + thermostat.household_token
      unless REDIS.get(redis_key).present?
        last_number = Reading.joins(:thermostat).
          where(thermostats: {household_token: thermostat.household_token}).maximum(:number).to_i
        REDIS.set redis_key, last_number, nx: true
      end
      REDIS.incr(redis_key).to_i
    end

    def last_number(thermostat_or_id)
      thermostat = thermostat_or_id.is_a?(Thermostat) ? thermostat_or_id : Thermostat.find(thermostat_or_id)

      REDIS.get(CACHE_KEY_NUMBER + thermostat.household_token).to_i
    end
  end

  private

  def set_defaults
    self.id ||= self.class.next_id!
    self.number ||= self.class.next_number! self.thermostat
  end

  def remove_from_redis
    REDIS.del CACHE_KEY_DATA + id.to_s
  end
end
