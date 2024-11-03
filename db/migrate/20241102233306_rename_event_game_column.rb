class RenameEventGameColumn < ActiveRecord::Migration[7.1]
  def change
    rename_column :events, :game, :game_slug
  end
end
