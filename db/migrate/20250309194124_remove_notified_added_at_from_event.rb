class RemoveNotifiedAddedAtFromEvent < ActiveRecord::Migration[8.0]
  def change
    remove_column :events, :notified_added_at
  end
end
