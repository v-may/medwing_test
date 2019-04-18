class CreateReadings < ActiveRecord::Migration[5.2]
  def change
    create_table :readings do |t|
      t.references :thermostat
      t.integer :number
      t.float :temperature
      t.float :humidity
      t.float :battery_charge
    end
  end
end
