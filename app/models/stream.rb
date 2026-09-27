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
class Stream < ApplicationRecord
  PLATFORM_TWITCH = 'twitch'
  PLATFORM_YOUTUBE = 'youtube'

  # The only status we actually care about.
  STATUS_LIVE = 'live'

  belongs_to :tournament

  def live?
    status == STATUS_LIVE
  end
end
