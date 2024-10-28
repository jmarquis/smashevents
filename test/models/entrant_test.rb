# == Schema Information
#
# Table name: entrants
#
#  id                 :bigint           not null, primary key
#  rank               :integer
#  seed               :integer
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  event_id           :bigint           not null
#  player_id          :bigint           not null
#  startgg_entrant_id :integer
#
# Indexes
#
#  index_entrants_on_event_id            (event_id)
#  index_entrants_on_player_id           (player_id)
#  index_entrants_on_startgg_entrant_id  (startgg_entrant_id) UNIQUE
#
require "test_helper"

class EntrantTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
