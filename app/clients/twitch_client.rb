class TwitchClient

  @@client = nil

  class << self
    delegate :get_streams, to: :client

    def client
      return @@client if @@client

      tokens = TwitchOAuth2::Tokens.new(
        client: {
          client_id: Rails.application.credentials.dig(:twitch, :client_id),
          client_secret: Rails.application.credentials.dig(:twitch, :client_secret)
        }
      )

      @@client = Twitch::Client.new(tokens:)
    end

  end

end
