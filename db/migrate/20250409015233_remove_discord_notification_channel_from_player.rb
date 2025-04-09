class RemoveDiscordNotificationChannelFromPlayer < ActiveRecord::Migration[8.0]
  def change
    remove_column :players, :discord_notification_channel
  end
end
