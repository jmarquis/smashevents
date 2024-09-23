# == Schema Information
#
# Table name: tournaments
#
#  id                :bigint           not null, primary key
#  banner_image_url  :string
#  city              :string
#  country           :string
#  end_at            :datetime
#  hashtag           :string
#  name              :string
#  profile_image_url :string
#  slug              :string
#  start_at          :datetime
#  state             :string
#  stream_data       :json
#  timezone          :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  startgg_id        :integer
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
