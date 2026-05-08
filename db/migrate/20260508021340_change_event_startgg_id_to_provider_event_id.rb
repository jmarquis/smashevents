class ChangeEventStartggIdToProviderEventId < ActiveRecord::Migration[8.0]
  def change
    rename_column :events, :startgg_id, :provider_event_id
  end
end
