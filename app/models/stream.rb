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
  belongs_to :game, foreign_key: :game_name, primary_key: :twitch_name, optional: true

  normalizes :platform, with: ->(platform) { platform.downcase }

  # Channel names are case insensitive on every platform we care about, but we
  # keep the original casing for display.
  scope :with_channel, ->(channel) { where('LOWER(streams.channel) = ?', channel&.downcase) }

  def channel?(other_channel)
    channel.present? && channel.casecmp?(other_channel.to_s)
  end

  def live?
    status == STATUS_LIVE
  end

  def url
    case platform
    when PLATFORM_TWITCH
      "https://twitch.tv/#{channel}"
    when PLATFORM_YOUTUBE
      if youtube_channel_id.present?
        "https://youtube.com/channel/#{youtube_channel_id}/live"
      else
        # Just hope this works I guess. It's not super clear how well we should
        # expect what people type into startgg to translate to a URL like this.
        "https://youtube.com/#{channel}"
      end
    end
  end
end
