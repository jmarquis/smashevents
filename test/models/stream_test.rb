# == Schema Information
#
# Table name: streams
#
#  id                 :bigint           not null, primary key
#  channel            :string
#  game_name          :string
#  platform           :string
#  status             :string
#  title              :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  provider_stream_id :string
#  tournament_id      :bigint           not null
#  youtube_channel_id :string
#
# Indexes
#
#  index_streams_on_tournament_id  (tournament_id)
#
require "test_helper"

class StreamTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
