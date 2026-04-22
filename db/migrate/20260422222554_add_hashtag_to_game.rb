class AddHashtagToGame < ActiveRecord::Migration[8.0]
  def change
    add_column :games, :hashtag, :string
  end
end
