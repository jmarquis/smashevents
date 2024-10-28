class AddFieldsToEntrant < ActiveRecord::Migration[7.1]
  def change
    add_column :entrants, :startgg_entrant_id, :integer
    add_index :entrants, :startgg_entrant_id, unique: true
    add_column :entrants, :seed, :integer
    add_column :entrants, :rank, :integer
  end
end
