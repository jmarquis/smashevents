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
        [Gateway.with_retries(15, batch_size: 15) do |batch_size|
          Gateway.tournaments(
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
        Gateway.with_retries(5) do
          Gateway.tournament(slug:)
        end
      end

      def event_state(provider_event_id:)
        event = Gateway.with_retries(5) do
          Gateway.event(id: provider_event_id)
        end

        event&.state
      end

      def event_entrants(provider_event_id:, game:, page:, cursor:)
        [Gateway.with_retries(20, batch_size: ENTRANT_SYNC_BATCH_SIZE) do |batch_size|
          Gateway.event_entrants(
            event_id: provider_event_id,
            game:,
            batch_size:,
            page:
          )
        end, nil]
      end

      def in_progress_sets(provider_event_id:, batch_size:, page:)
        Gateway.with_retries(5, batch_size:) do |batch_size|
          Gateway.in_progress_sets(event_id: provider_event_id, batch_size:, page:)
        end
      end

    end
  end
end
