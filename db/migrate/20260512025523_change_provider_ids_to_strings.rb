class ChangeProviderIdsToStrings < ActiveRecord::Migration[8.0]
  def change
    change_column :tournaments, :provider_tournament_id, :string
    change_column :events, :provider_event_id, :string
    change_column :entrants, :provider_entrant_id, :string
    change_column :players, :provider_player_id, :string
    change_column :players, :provider_user_id, :string
  end
end
