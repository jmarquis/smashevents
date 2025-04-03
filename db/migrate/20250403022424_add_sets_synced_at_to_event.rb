class AddSetsSyncedAtToEvent < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :sets_synced_at, :datetime
  end
end
