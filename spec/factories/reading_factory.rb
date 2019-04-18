FactoryBot.define do
  factory :reading do
    thermostat
    temperature { 18.0 }
    humidity { 50.0 }
    battery_charge { 100.0 }
  end
end