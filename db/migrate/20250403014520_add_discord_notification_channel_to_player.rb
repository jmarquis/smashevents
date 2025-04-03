class AddDiscordNotificationChannelToPlayer < ActiveRecord::Migration[8.0]
  def change
    add_column :players, :discord_notification_channel, :string
  end
end
