class CreateGames < ActiveRecord::Migration[7.1]
  def change
    create_table :games do |t|
      t.string :slug
      t.string :name
      t.string :twitch_name
      t.integer :startgg_id
      t.string :rankings_regex
      t.integer :ingestion_threshold
      t.integer :display_threshold

      t.timestamps
    end
    add_index :games, :slug
    add_index :games, :twitch_name
    add_index :games, :startgg_id
  end
end
