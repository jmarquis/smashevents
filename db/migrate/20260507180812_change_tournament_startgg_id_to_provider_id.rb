class ChangeTournamentStartggIdToProviderId < ActiveRecord::Migration[8.0]
  def change
    rename_column :tournaments, :startgg_id, :provider_tournament_id
  end
end
