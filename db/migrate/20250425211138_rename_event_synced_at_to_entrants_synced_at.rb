class RenameEventSyncedAtToEntrantsSyncedAt < ActiveRecord::Migration[8.0]
  def change
    rename_column :events, :synced_at, :entrants_synced_at
  end
end
