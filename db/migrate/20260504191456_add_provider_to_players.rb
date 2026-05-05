class AddProviderToPlayers < ActiveRecord::Migration[8.0]
  def change
    add_column :players, :provider, :string
  end
end
