# == Schema Information
#
# Table name: discord_servers
#
#  id                        :bigint           not null, primary key
#  note                      :string
#  player_subscription_limit :integer
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  discord_server_id         :string
#

require "test_helper"

class DiscordServerTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
