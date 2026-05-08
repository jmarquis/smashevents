class RenamePlayerStartggColumnsToProvider < ActiveRecord::Migration[8.0]
  def change
    rename_column :players, :startgg_player_id, :provider_player_id
    rename_column :players, :startgg_user_id, :provider_user_id
    rename_column :players, :startgg_user_slug, :provider_user_slug
  end
end
