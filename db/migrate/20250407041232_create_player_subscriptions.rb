class CreatePlayerSubscriptions < ActiveRecord::Migration[8.0]
  def change
    create_table :player_subscriptions do |t|
      t.references :player, null: false
      t.string :discord_server_id
      t.string :discord_channel_id

      t.timestamps
    end

    add_index :player_subscriptions, [:discord_server_id, :discord_channel_id]
  end
end
