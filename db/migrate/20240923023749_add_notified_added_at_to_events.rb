class AddNotifiedAddedAtToEvents < ActiveRecord::Migration[7.1]
  def change
    add_column :events, :notified_added_at, :datetime
  end
end
