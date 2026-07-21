module Provider
  class Parrygg < Base
    PROVIDER_NAME = 'parrygg'

    class << self

      def base_url
        'https://parry.gg'
      end

      def tournaments(
        page:,
        cursor:,
        before_date: nil,
        after_date: nil,
        updated_after: nil,
        sort_order: nil
      )
        # As of July 2026, the Parrygg API doesn't support filtering by start
        # date so we can't use before_date or after_date. It also doesn't
        # support any useful sorting so we can't use sort_order. Pain.
        result = Api::Parrygg.tournaments(
          batch_size: 20,
          cursor:,
          updated_after:
        )

        [result[:tournaments], result.dig(:paginationResponse, :nextCursor, :id)]
      end

      def tournament(slug:)
        result = Api::Parrygg.tournament(slug:)
        result[:tournament]
      end

      def event_state(provider_event_id:)
        result = Api::Parrygg.event(id: provider_event_id)
        state = result.dig(:event, :state)

        # Map parrygg state to equivalent startgg state since that's what we've
        # always stored & reasoned about.
        Factory::Parrygg.event_state(state)
      end

      def event_entrants(provider_event_id:, game:, page:, cursor:)
        # Simulate a blank page after the first page to stop the loop, because
        # as of July 2026 parrygg doesn't currently paginate entrants.
        return [[], nil] if page > 1

        result = Api::Parrygg.event_entrants(event_id: provider_event_id)
        [result[:eventEntrants]]
      end

      def event_winner_entrant(provider_event_id:)
        result = Api::Parrygg.event_placements(event_id: provider_event_id)
        binding.pry
      end

      def sleep_time
        0.1
      end

    end
  end
end
