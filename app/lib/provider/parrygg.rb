module Provider
  class Parrygg < Base
    PROVIDER_NAME = 'parrygg'

    class << self

      def tournaments(page:, cursor:, after_date:, updated_after:)
        # TODO: with_retries
        result = Api::Parrygg.tournaments(
          batch_size: 20,
          cursor:,
          updated_after:
        )

        [result[:tournaments], result.dig(:paginationResponse, :nextCursor, :id)]
      end

      def tournament(slug:)
        # TODO: with_retries
        Api::Parrygg.tournament(slug:)
      end

      def event_entrants(provider_event_id:, game:, page:, cursor:)
        # Simulate a blank page after the first page to stop the loop, because
        # parrygg doesn't currently paginate entrants.
        return [[], nil] if page > 1

        [Api::Parrygg.event_entrants(
          event_id: provider_event_id
        )[:eventEntrants]]
      end

      def sleep_time
        0.1
      end

    end
  end
end
