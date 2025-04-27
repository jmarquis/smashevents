class AddLastUpsetTweetIdToEvent < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :last_upset_tweet_id, :string
  end
end
