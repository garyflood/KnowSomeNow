class AddUserRefToDevices < ActiveRecord::Migration[8.1]
  def change
    add_reference :devices, :user, null: false, foreign_key: true
  end
end
