module Provider
  class Startgg < Base
    PROVIDER_NAME = 'startgg'
    ENTRANT_SYNC_BATCH_SIZE = 50

    class << self

      def base_url
        'https://start.gg'
      end

      def tournaments(page:, cursor:, after_date:, updated_after:)
        [Api::Startgg.with_retries(5, batch_size: 15) do |batch_size|
          Api::Startgg.tournaments(
            batch_size:,
            page:,
            after_date:,
            updated_after:
          )
        end, nil]
      end

      def tournament(slug:)
        Api::Startgg.with_retries(5) do
          Api::Startgg.tournament(slug:)
        end
      end

      def event_state(provider_event_id:)
        event = Api::Startgg.with_retries(5) do
          Api::Startgg.event(id: provider_event_id)
        end

        event&.state
      end

      def event_entrants(provider_event_id:, game:, page:, cursor:)
        [Api::Startgg.with_retries(5, batch_size: ENTRANT_SYNC_BATCH_SIZE) do |batch_size|
          Api::Startgg.event_entrants(
            event_id: provider_event_id,
            game:,
            batch_size:,
            page:
          )
        end, nil]
      end

    end
  end
end
