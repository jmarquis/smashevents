class AddRealPlayerCountToEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :events, :real_player_count, :integer
  end
end
