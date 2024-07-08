class RenameTournamentGamesToEvents < ActiveRecord::Migration[7.1]
  def change
    rename_table :tournament_games, :events
  end
end
