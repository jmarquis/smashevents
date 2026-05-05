class AddProviderToTournamentOverride < ActiveRecord::Migration[8.0]
  def change
    add_column :tournament_overrides, :provider, :string
  end
end
