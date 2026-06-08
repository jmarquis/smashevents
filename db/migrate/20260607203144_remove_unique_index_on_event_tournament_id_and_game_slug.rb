class RemoveUniqueIndexOnEventTournamentIdAndGameSlug < ActiveRecord::Migration[8.1]
  def change
    remove_index :events, [:tournament_id, :game_slug], unique: true
  end
end
