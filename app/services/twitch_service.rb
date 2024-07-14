class TwitchService

  def self.live_streams(streams:)
    TwitchClient.get_streams(user_login: streams).data.reduce({}) do |streams, stream|
      streams[stream.user_name.downcase] = {
        name: stream.user_name,
        game: stream.game,
        title: stream.title
      }
      streams
    end
  end

end
