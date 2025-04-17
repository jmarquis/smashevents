class AddDiscordRoleIdToPlayerSubscription < ActiveRecord::Migration[8.0]
  def change
    add_column :player_subscriptions, :discord_role_id, :string
  end
end
