# == Schema Information
#
# Table name: players
#
#  id                :bigint           not null, primary key
#  tag               :string
#  twitter_username  :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  startgg_player_id :integer
#  startgg_user_id   :integer
#
# Indexes
#
#  index_players_on_startgg_player_id  (startgg_player_id) UNIQUE
#  index_players_on_startgg_user_id    (startgg_user_id) UNIQUE
#  index_players_on_tag                (tag)
#
require "test_helper"

class PlayerTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
