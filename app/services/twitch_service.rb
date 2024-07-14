class TwitchService

  STATUS_LIVE = 'live'

  def self.live_streams(streams:)
    TwitchClient.get_streams(user_login: streams).data.map(&:user_name)
  end

end
