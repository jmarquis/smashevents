class CreateDiscordServers < ActiveRecord::Migration[8.0]
  def change
    create_table :discord_servers do |t|
      t.string :discord_server_id
      t.integer :player_subscription_limit
      t.string :note

      t.timestamps
    end
  end
end
