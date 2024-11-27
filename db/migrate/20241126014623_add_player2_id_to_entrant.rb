class AddPlayer2IdToEntrant < ActiveRecord::Migration[8.0]
  def change
    add_reference :entrants, :player2
  end
end
