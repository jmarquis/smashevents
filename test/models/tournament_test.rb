# == Schema Information
#
# Table name: tournaments
#
#  id                     :integer          not null, primary key
#  provider_tournament_id :integer
#  slug                   :string
#  name                   :string
#  start_at               :datetime
#  end_at                 :datetime
#  city                   :string
#  state                  :string
#  country                :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  stream_data            :json
#  timezone               :string
#  hashtag                :string
#  banner_image_url       :string
#  profile_image_url      :string
#  provider               :string
#
# Indexes
#
#  index_tournaments_on_name                    (name)
#  index_tournaments_on_provider_tournament_id  (provider_tournament_id) UNIQUE
#  index_tournaments_on_start_at                (start_at)
#

require "test_helper"

class TournamentTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
