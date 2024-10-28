class CreatePlayers < ActiveRecord::Migration[7.1]
  def change
    create_table :players do |t|
      t.integer :startgg_player_id
      t.integer :startgg_user_id
      t.string :tag
      t.string :twitter_username

      t.timestamps
    end

    add_index :players, :tag
    add_index :players, :startgg_player_id, unique: true
    add_index :players, :startgg_user_id, unique: true
  end
end
