# == Schema Information
#
# Table name: event_sets
#
#  id                :bigint           not null, primary key
#  completed_at      :datetime
#  started_at        :datetime
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  discord_post_id   :string
#  entrant1_id       :bigint           not null
#  entrant2_id       :bigint           not null
#  event_id          :bigint           not null
#  provider_set_id   :string           not null
#  stream_id         :bigint
#  winner_entrant_id :bigint
#
# Indexes
#
#  index_event_sets_on_entrant1_id        (entrant1_id)
#  index_event_sets_on_entrant2_id        (entrant2_id)
#  index_event_sets_on_event_id           (event_id)
#  index_event_sets_on_provider_set_id    (provider_set_id)
#  index_event_sets_on_stream_id          (stream_id)
#  index_event_sets_on_winner_entrant_id  (winner_entrant_id)
#
require "test_helper"

class EventSetTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
