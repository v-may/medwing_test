class Reading < ApplicationRecord
  belongs_to :thermostat

  before_create :ensure_id
  after_create :remove_from_redis

  CACHE_KEY_LAST_ID = "#{Rails.env}_reading_id"
  CACHE_KEY_ID = "#{Rails.env}_reading_"

  class << self
    def setup_redis
      REDIS.set CACHE_KEY_LAST_ID, Reading.maximum(:id).to_i, nx: true
    end

    def reset_redis
      REDIS.del CACHE_KEY_LAST_ID
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
      opts[:id] = next_id! unless opts[:id]

      delay.create! opts

      REDIS.set (CACHE_KEY_ID + opts[:id].to_s), opts.to_json

      new opts
    end

    def find(id)
      cached_value = REDIS.get(CACHE_KEY_ID + id.to_s)
      if cached_value
        cached_opts = JSON.parse(cached_value)
        return new(cached_opts)
      end

      super
    end
  end

  def ensure_id
    self.id ||= self.class.next_id!
  end

  private

  def remove_from_redis
    REDIS.del CACHE_KEY_ID + id.to_s
  end
end
