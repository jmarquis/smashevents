require 'google/protobuf/well_known_types'

module Api
  class Parrygg
    extend Instrumentable

    @client = nil

    class << self

      def tournaments(batch_size:, cursor: nil, updated_after: 6.hours.ago)
        instrument('tournaments') do
          execute('parrygg.services.TournamentService/GetTournaments', {
            filter: {
              event_updated_since: Google::Protobuf::Timestamp.new.from_time(updated_after)
            },
            pagination_request: {
              page_size: batch_size,
              cursor: nil
            }
          })
        end
      end

      def tournament(slug:)
        instrument('tournament') do
          execute('parrygg.services.TournamentService/GetTournament', {
            tournament_slug: slug
          })[:tournament]
        end
      end

      def event_entrants(event_id:)
        instrument('event_entrants') do
          execute('parrygg.services.EventService/GetEventEntrants', {
            event_identifier: {
              id: event_id
            }
          })
        end
      end

      def games
        execute('parrygg.services.GameService/GetGames')
      end

      private

      def execute(url, body = nil)
        response = client.post(url, body).body
        raise Api::ParryggError, response if response.is_a? String

        response.with_indifferent_access
      end

      def client
        return @client if @client

        @client = Faraday.new(url: 'https://grpcweb.parry.gg', headers: {
          'X-API-KEY': Rails.application.credentials.dig(:parrygg, :api_key)
        }) do |builder|
          builder.request :json
          builder.response :json
          # builder.response :raise_error
        end
      end

    end
  end
end
