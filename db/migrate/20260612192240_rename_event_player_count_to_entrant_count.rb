class RenameEventPlayerCountToEntrantCount < ActiveRecord::Migration[8.1]
  def change
    rename_column :events, :player_count, :entrant_count
  end
end
