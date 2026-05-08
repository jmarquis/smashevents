# == Schema Information
#
# Table name: players
#
#  id                 :integer          not null, primary key
#  provider_player_id :integer
#  provider_user_id   :integer
#  tag                :string
#  twitter_username   :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  name               :string
#  provider_user_slug :string
#  provider           :string
#
# Indexes
#
#  gin_index_players_on_tag             (tag)
#  index_players_on_provider_player_id  (provider_player_id) UNIQUE
#  index_players_on_provider_user_id    (provider_user_id) UNIQUE
#  index_players_on_provider_user_slug  (provider_user_slug)
#  index_players_on_tag                 (tag)
#

require "test_helper"

class PlayerTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
