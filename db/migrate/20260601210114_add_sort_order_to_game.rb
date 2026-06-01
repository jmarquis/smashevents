class AddSortOrderToGame < ActiveRecord::Migration[8.1]
  def change
    add_column :games, :sort_order, :integer
  end
end
