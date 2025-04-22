class AddStartggUserSlugToPlayer < ActiveRecord::Migration[8.0]
  def change
    add_column :players, :startgg_user_slug, :string
    add_index :players, :startgg_user_slug
  end
end
