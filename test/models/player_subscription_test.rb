# == Schema Information
#
# Table name: player_subscriptions
#
#  id                  :bigint           not null, primary key
#  discord_server_name :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  discord_channel_id  :string
#  discord_role_id     :string
#  discord_server_id   :string
#  player_id           :bigint           not null
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
