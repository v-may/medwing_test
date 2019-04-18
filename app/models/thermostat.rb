class Thermostat < ApplicationRecord
  has_many :readings, dependent: :destroy
end
