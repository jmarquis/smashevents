class AddNameToEvent < ActiveRecord::Migration[8.1]
  def change
    add_column :events, :name, :string
  end
end
