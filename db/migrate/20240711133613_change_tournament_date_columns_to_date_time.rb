class ChangeTournamentDateColumnsToDateTime < ActiveRecord::Migration[7.1]
  def change
    change_column :tournaments, :start_at, :datetime
    change_column :tournaments, :end_at, :datetime
    add_column :tournaments, :timezone, :string
  end
end
