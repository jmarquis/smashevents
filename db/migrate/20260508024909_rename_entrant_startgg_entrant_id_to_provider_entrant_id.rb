class RenameEntrantStartggEntrantIdToProviderEntrantId < ActiveRecord::Migration[8.0]
  def change
    rename_column :entrants, :startgg_entrant_id, :provider_entrant_id
  end
end
