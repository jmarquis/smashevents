class AddLastSyncedAtToEvent < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :synced_at, :datetime
  end
end
