class UpdateUniqueProviderKeys < ActiveRecord::Migration[8.0]
  def change
    remove_index :tournaments, :provider_tournament_id
    add_index :tournaments, [:provider, :provider_tournament_id], unique: true

    remove_index :entrants, :provider_entrant_id
    add_column :entrants, :provider, :string
    add_index :entrants, [:provider, :provider_entrant_id], unique: true

    remove_index :players, :provider_player_id
    remove_index :players, :provider_user_id
    add_index :players, [:provider, :provider_player_id], unique: true
    add_index :players, [:provider, :provider_user_id], unique: true
  end
end
