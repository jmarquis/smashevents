class AddUniqueIndexToDiscordServerId < ActiveRecord::Migration[8.1]
  def change
    add_index :discord_servers, :discord_server_id, unique: true
  end
end
