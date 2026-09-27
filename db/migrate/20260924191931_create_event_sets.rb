class CreateEventSets < ActiveRecord::Migration[8.1]
  def change
    create_table :event_sets do |t|
      t.references :event, null: false
      t.string :provider_set_id
      t.references :entrant1, null: false
      t.references :entrant2, null: false
      t.string :discord_post_id
      t.references :winner_entrant, null: false

      t.timestamps
    end
    add_index :event_sets, :provider_set_id
  end
end
