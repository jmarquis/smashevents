class AddWinnerEntrantIdToEvent < ActiveRecord::Migration[8.0]
  def change
    add_reference :events, :winner_entrant
  end
end
