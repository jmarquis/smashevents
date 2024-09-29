class AddRankedPlayerCountToEvents < ActiveRecord::Migration[7.1]
  def change
    add_column :events, :ranked_player_count, :integer
  end
end
