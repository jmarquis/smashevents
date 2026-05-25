module Api
  class Twitch
    extend Instrumentable

    @client = nil

    class << self

      def streams(streams:)
        instrument('streams') do
          client.streams.list(user_login: streams).data.reduce({}) do |streams, stream|
            streams[stream.user_name.downcase] = {
              name: stream.user_name,
              game: stream.game_name,
              title: stream.title
            }
            streams
          end
        end
      end

      def client
        return @client if @client

        oauth = ::Twitch::OAuth.new(
          client_id: Rails.application.credentials.dig(:twitch, :client_id),
          client_secret: Rails.application.credentials.dig(:twitch, :client_secret)
        )

        token = oauth.create(grant_type: 'client_credentials')

        @client = ::Twitch::Client.new(
          client_id: Rails.application.credentials.dig(:twitch, :client_id),
          access_token: token.access_token
        )
      end

    end
  end
end
