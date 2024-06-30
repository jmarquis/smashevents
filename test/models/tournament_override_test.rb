# == Schema Information
#
# Table name: tournament_overrides
#
#  id         :bigint           not null, primary key
#  include    :boolean
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  startgg_id :integer
#
# Indexes
#
#  index_tournament_overrides_on_include     (include)
#  index_tournament_overrides_on_startgg_id  (startgg_id) UNIQUE
#
require "test_helper"

class TournamentOverrideTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
