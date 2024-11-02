class AddIsSeededToEvent < ActiveRecord::Migration[7.1]
  def change
    add_column :events, :is_seeded, :boolean
  end
end
