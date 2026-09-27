class CreateStreams < ActiveRecord::Migration[8.1]
  def change
    create_table :streams do |t|
      t.string :provider_stream_id
      t.references :tournament, null: false
      t.string :channel
      t.string :platform
      t.string :status
      t.string :youtube_channel_id
      t.string :game_name
      t.string :title

      t.timestamps
    end
  end
end
