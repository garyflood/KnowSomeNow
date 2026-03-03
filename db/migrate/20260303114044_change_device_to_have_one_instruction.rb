class ChangeDeviceToHaveOneInstruction < ActiveRecord::Migration[8.1]
  def change
    remove_index :instructions, :device_id if index_exists?(:instructions, :device_id)
    add_index :instructions, :device_id, unique: true
  end
end
