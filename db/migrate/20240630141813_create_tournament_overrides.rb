class CreateTournamentOverrides < ActiveRecord::Migration[7.1]
  def change
    create_table :tournament_overrides do |t|
      t.string :slug
      t.boolean :include

      t.timestamps
    end

    add_index :tournament_overrides, :slug, unique: true
    add_index :tournament_overrides, :include
  end
end
