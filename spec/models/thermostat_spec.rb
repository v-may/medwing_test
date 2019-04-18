require 'rails_helper'

RSpec.describe Thermostat, type: :model do
  it { should have_many(:readings).dependent(:destroy) }
end
