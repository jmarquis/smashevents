class CreateTournaments < ActiveRecord::Migration[7.1]
  def change
    create_table :tournaments do |t|
      t.string :slug
      t.string :name
      t.date :start_at
      t.date :end_at
      t.string :games, array: true
      t.string :city
      t.string :state
      t.string :country
      t.integer :player_count
      t.string :featured_players

      t.timestamps
    end
    add_index :tournaments, :name
    add_index :tournaments, :start_at
    add_index :tournaments, :games, using: 'gin'
  end
end
