class CreateTournamentOverrides < ActiveRecord::Migration[7.1]
  def change
    create_table :tournament_overrides do |t|
      t.integer :startgg_id
      t.boolean :include

      t.timestamps
    end

    add_index :tournament_overrides, :startgg_id, unique: true
    add_index :tournament_overrides, :include
  end
end
