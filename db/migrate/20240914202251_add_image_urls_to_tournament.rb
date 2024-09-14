class AddImageUrlsToTournament < ActiveRecord::Migration[7.1]
  def change
    add_column :tournaments, :banner_image_url, :string
    add_column :tournaments, :profile_image_url, :string
  end
end
