# == Schema Information
#
# Table name: games
#
#  id                  :bigint           not null, primary key
#  display_threshold   :integer
#  ingestion_threshold :integer
#  name                :string
#  rankings_regex      :string
#  slug                :string
#  twitch_name         :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  startgg_id          :integer
#
# Indexes
#
#  index_games_on_slug         (slug)
#  index_games_on_startgg_id   (startgg_id)
#  index_games_on_twitch_name  (twitch_name)
#
require "test_helper"

class GameTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
