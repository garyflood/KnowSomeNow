class AddImageToDevices < ActiveRecord::Migration[8.1]
  def change
    add_column :devices, :image, :string
  end
end
