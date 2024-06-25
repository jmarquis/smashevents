# == Schema Information
#
# Table name: tournaments
#
#  id               :bigint           not null, primary key
#  city             :string
#  country          :string
#  end_at           :date
#  featured_players :string
#  games            :string           is an Array
#  name             :string
#  player_count     :integer
#  slug             :string
#  start_at         :date
#  state            :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  startgg_id       :integer
#
# Indexes
#
#  index_tournaments_on_games       (games) USING gin
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
