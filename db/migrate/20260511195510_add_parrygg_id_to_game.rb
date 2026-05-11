class AddParryggIdToGame < ActiveRecord::Migration[8.0]
  def change
    add_column :games, :parrygg_id, :string
  end
end
