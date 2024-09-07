class Twitchy
  @client = nil

  class << self

    def live_streams(streams:)
      client.get_streams(user_login: streams).data.reduce({}) do |streams, stream|
        streams[stream.user_name.downcase] = {
          name: stream.user_name,
          game: stream.game_name,
          title: stream.title
        }
        streams
      end
    end

    def client
      return @client if @client

      tokens = TwitchOAuth2::Tokens.new(
        client: {
          client_id: Rails.application.credentials.dig(:twitch, :client_id),
          client_secret: Rails.application.credentials.dig(:twitch, :client_secret)
        }
      )

      @client = Twitch::Client.new(tokens:)
    end

  end
end
