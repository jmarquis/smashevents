class AddEndAtIndexToTournament < ActiveRecord::Migration[8.1]
  def change
    add_index :tournaments, :end_at
  end
end
