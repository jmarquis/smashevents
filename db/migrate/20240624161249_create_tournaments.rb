class CreateTournaments < ActiveRecord::Migration[7.1]
  def change
    create_table :tournaments do |t|
      t.integer :startgg_id
      t.string :slug
      t.string :name
      t.date :start_at
      t.date :end_at
      t.string :city
      t.string :state
      t.string :country
      t.integer :melee_player_count
      t.integer :ultimate_player_count
      t.string :melee_featured_players, array: true
      t.string :ultimate_featured_players, array: true

      t.timestamps
    end
    add_index :tournaments, :startgg_id, unique: true
    add_index :tournaments, :name
    add_index :tournaments, :start_at
  end
end
