class CreateInstructions < ActiveRecord::Migration[8.1]
  def change
    create_table :instructions do |t|
      t.text :steps

      t.timestamps
    end
  end
end
