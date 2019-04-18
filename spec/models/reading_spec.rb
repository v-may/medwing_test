require 'rails_helper'

RSpec.describe Reading, type: :model do
  it { should belong_to(:thermostat) }
end
