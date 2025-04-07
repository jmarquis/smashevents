# == Schema Information
#
# Table name: player_subscriptions
#
#  id                 :integer          not null, primary key
#  player_id          :integer          not null
#  discord_server_id  :string
#  discord_channel_id :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
# Indexes
#
#  idx_on_discord_server_id_discord_channel_id_569c7cf4d2  (discord_server_id,discord_channel_id)
#  index_player_subscriptions_on_player_id                 (player_id)
#

require "test_helper"

class PlayerSubscriptionTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
