class AddStreamToSet < ActiveRecord::Migration[8.1]
  def change
    add_reference :event_sets, :stream
  end
end
