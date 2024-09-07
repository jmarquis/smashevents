class AddHashtagToTournament < ActiveRecord::Migration[7.1]
  def change
    add_column :tournaments, :hashtag, :string
  end
end
