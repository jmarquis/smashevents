class MakeEventSetsWinnerEntrantIdNullable < ActiveRecord::Migration[8.1]
  def change
    change_column_null :event_sets, :winner_entrant_id, true
  end
end
