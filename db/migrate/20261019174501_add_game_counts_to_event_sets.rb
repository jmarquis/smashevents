class AddGameCountsToEventSets < ActiveRecord::Migration[8.1]
  def change
    add_column :event_sets, :entrant1_score, :integer
    add_column :event_sets, :entrant2_score, :integer
  end
end
