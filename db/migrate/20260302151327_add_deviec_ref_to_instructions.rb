class AddDeviecRefToInstructions < ActiveRecord::Migration[8.1]
  def change
    add_reference :instructions, :device, null: false, foreign_key: true
  end
end
