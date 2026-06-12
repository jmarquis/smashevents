class AddEntrantSizeToEvent < ActiveRecord::Migration[8.1]
  def change
    add_column :events, :entrant_size, :integer
  end
end
