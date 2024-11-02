class BetterEntrantIndex < ActiveRecord::Migration[7.1]
  def change
    add_index :entrants, [:event_id, :seed]
    add_index :entrants, [:event_id, :rank]
  end
end
