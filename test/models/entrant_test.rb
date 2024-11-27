# == Schema Information
#
# Table name: entrants
#
#  id                 :integer          not null, primary key
#  player_id          :integer          not null
#  event_id           :integer          not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  startgg_entrant_id :integer
#  seed               :integer
#  rank               :integer
#  player2_id         :integer
#
# Indexes
#
#  index_entrants_on_event_id            (event_id)
#  index_entrants_on_event_id_and_rank   (event_id,rank)
#  index_entrants_on_event_id_and_seed   (event_id,seed)
#  index_entrants_on_player2_id          (player2_id)
#  index_entrants_on_player_id           (player_id)
#  index_entrants_on_startgg_entrant_id  (startgg_entrant_id) UNIQUE
#

require "test_helper"

class EntrantTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
