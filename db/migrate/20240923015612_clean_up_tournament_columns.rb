class CleanUpTournamentColumns < ActiveRecord::Migration[7.1]
  def change
    remove_column :tournaments, :melee_player_count
    remove_column :tournaments, :melee_featured_players
    remove_column :tournaments, :ultimate_player_count
    remove_column :tournaments, :ultimate_featured_players
  end
end
