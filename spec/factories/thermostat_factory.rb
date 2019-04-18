FactoryBot.define do
  factory :thermostat do
    household_token { 'household-token' }
    location { 'Room 1, Apartment 123' }
  end
end