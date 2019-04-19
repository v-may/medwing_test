class Reading < ApplicationRecord
  belongs_to :thermostat

  before_create :ensure_id

  CACHE_KEY_ID = "#{Rails.env}_reading_id"

  def self.setup_redis
    REDIS.set CACHE_KEY_ID, Reading.maximum(:id).to_i, nx: true
  end

  def self.reset_redis
    REDIS.del CACHE_KEY_ID
    setup_redis
  end

  def self.next_id
    REDIS.incr CACHE_KEY_ID
  end

  def self.create_later!(options={})
    opts = { id: next_id }.merge(options)

    delay.create! opts.symbolize_keys

    new opts
  end

  def ensure_id
    self.id ||= self.class.next_id
  end
end
