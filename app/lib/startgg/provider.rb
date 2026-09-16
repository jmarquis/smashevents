module Startgg
  class Provider < ::Provider
    PROVIDER_NAME = 'startgg'
    ENTRANT_SYNC_BATCH_SIZE = 50

    class << self

      def base_url
        'https://start.gg'
      end

      def tournaments(
        page:,
        cursor:,
        before_date: nil,
        after_date: nil,
        updated_after: nil,
        sort_order: nil
      )
        [Api.with_retries(15, batch_size: 15) do |batch_size|
          Api.tournaments(
            batch_size:,
            page:,
            before_date:,
            after_date:,
            updated_after:,
            sort_order:
          )
        end, nil]
      end

      def tournament(slug:)
        Api.with_retries(5) do
          Api.tournament(slug:)
        end
      end

      def event_state(provider_event_id:)
        event = Api.with_retries(5) do
          Api.event(id: provider_event_id)
        end

        event&.state
      end

      def event_entrants(provider_event_id:, game:, page:, cursor:)
        [Api.with_retries(20, batch_size: ENTRANT_SYNC_BATCH_SIZE) do |batch_size|
          Api.event_entrants(
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
