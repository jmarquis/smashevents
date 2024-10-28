class CreateEntrants < ActiveRecord::Migration[7.1]
  def change
    create_table :entrants do |t|
      t.references :player, null: false
      t.references :event, null: false

      t.timestamps
    end
  end
end
