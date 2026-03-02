class CreateDevices < ActiveRecord::Migration[8.1]
  def change
    create_table :devices do |t|
      t.string :name
      t.string :module
      t.text :system_prompt

      t.timestamps
    end
  end
end
