class AddDiscordServerNameToPlayerSubscription < ActiveRecord::Migration[8.0]
  def change
    add_column :player_subscriptions, :discord_server_name, :string
  end
end
