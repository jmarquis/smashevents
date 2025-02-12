class AddGinIndexToPlayerTag < ActiveRecord::Migration[8.0]
  def change
    enable_extension :pg_trgm
    add_index :players, :tag, opclass: :gin_trgm_ops, using: :gin, name: :gin_index_players_on_tag
  end
end
