class AddStartedAtAndCompletedAtToEventSets < ActiveRecord::Migration[8.1]
  def change
    add_column :event_sets, :started_at, :datetime
    add_column :event_sets, :completed_at, :datetime
  end
end
