class AddStreamDataToTournament < ActiveRecord::Migration[7.1]
  def change
    add_column :tournaments, :stream_data, :json
  end
end
