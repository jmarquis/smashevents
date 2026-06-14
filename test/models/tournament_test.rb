# == Schema Information
#
# Table name: tournaments
#
#  id                         :bigint           not null, primary key
#  banner_image_url           :string
#  city                       :string
#  country                    :string
#  end_at                     :datetime
#  hashtag                    :string
#  name                       :string
#  profile_image_url          :string
#  provider                   :string
#  slug                       :string
#  start_at                   :datetime
#  state                      :string
#  stream_data                :json
#  timezone                   :string
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  last_announcement_tweet_id :string
#  provider_tournament_id     :string
#
# Indexes
#
#  index_tournaments_on_name                                 (name)
#  index_tournaments_on_provider_and_provider_tournament_id  (provider,provider_tournament_id) UNIQUE
#  index_tournaments_on_start_at                             (start_at)
#

require "test_helper"

class TournamentTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
