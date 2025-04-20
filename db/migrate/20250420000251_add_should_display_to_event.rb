class AddShouldDisplayToEvent < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :should_display, :boolean
  end
end
