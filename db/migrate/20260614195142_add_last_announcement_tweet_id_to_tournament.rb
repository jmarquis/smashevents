class AddLastAnnouncementTweetIdToTournament < ActiveRecord::Migration[8.1]
  def change
    add_column :tournaments, :last_announcement_tweet_id, :string
  end
end
