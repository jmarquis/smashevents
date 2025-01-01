class DropFeaturedPlayersFromEvent < ActiveRecord::Migration[8.0]
  def change
    remove_column :events, :featured_players
  end
end
