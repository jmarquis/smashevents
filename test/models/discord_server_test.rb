# == Schema Information
#
# Table name: discord_servers
#
#  id                        :integer          not null, primary key
#  discord_server_id         :string
#  player_subscription_limit :integer
#  note                      :string
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#

require "test_helper"

class DiscordServerTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
