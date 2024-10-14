class AddStartAtToEvent < ActiveRecord::Migration[7.1]
  def change
    add_column :events, :start_at, :datetime
  end
end
