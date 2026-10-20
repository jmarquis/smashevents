class ScopeEntrantsProviderEntrantIdIndexToEvent < ActiveRecord::Migration[8.1]
  def change
    remove_index :entrants, [:provider, :provider_entrant_id], unique: true
    add_index :entrants, [:event_id, :provider, :provider_entrant_id], unique: true
  end
end
