class CreateTournamentGames < ActiveRecord::Migration[7.1]
  def change
    create_table :tournament_games do |t|
      t.references :tournament, null: false
      t.integer :startgg_id, null: false
      t.string :game, null: false
      t.integer :player_count
      t.string :featured_players, array: true

      t.timestamps
    end

    add_index :tournament_games, :startgg_id, unique: true
    add_index :tournament_games, [:tournament_id, :game], unique: true
  end
end
