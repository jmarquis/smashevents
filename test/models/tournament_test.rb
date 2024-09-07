# == Schema Information
#
# Table name: tournaments
#
#  id                        :bigint           not null, primary key
#  city                      :string
#  country                   :string
#  end_at                    :datetime
#  hashtag                   :string
#  melee_featured_players    :string           is an Array
#  melee_player_count        :integer
#  name                      :string
#  slug                      :string
#  start_at                  :datetime
#  state                     :string
#  stream_data               :json
#  timezone                  :string
#  ultimate_featured_players :string           is an Array
#  ultimate_player_count     :integer
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  startgg_id                :integer
#
# Indexes
#
#  index_tournaments_on_name        (name)
#  index_tournaments_on_start_at    (start_at)
#  index_tournaments_on_startgg_id  (startgg_id) UNIQUE
#
require "test_helper"

class TournamentTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
