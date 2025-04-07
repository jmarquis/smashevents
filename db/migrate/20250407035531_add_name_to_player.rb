class AddNameToPlayer < ActiveRecord::Migration[8.0]
  def change
    add_column :players, :name, :string
  end
end
