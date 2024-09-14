class AddBannerUrlToTournament < ActiveRecord::Migration[7.1]
  def change
    add_column :tournaments, :banner_url, :string
  end
end
