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
        # date so we can't really use before_date or after_date as intended. It
        # also doesn't support any useful sorting so we can't use sort_order.
        result = Api::Parrygg.with_retries(10) do
          Api::Parrygg.tournaments(
            batch_size: 20,
            cursor:,
            updated_after: after_date.present? && after_date > updated_after ? after_date : updated_after
          )
        end

        [result[:tournaments], result.dig(:paginationResponse, :nextCursor) || false]
      end

      def tournament(slug:)
        result = Api::Parrygg.with_retries(10) do
          Api::Parrygg.tournament(slug:)
        end

        result[:tournament]
      end

      def event_state(provider_event_id:)
        result = Api::Parrygg.with_retries(10) do
          Api::Parrygg.event(id: provider_event_id)
        end

        state = result.dig(:event, :state)

        # Map parrygg state to equivalent startgg state since that's what we've
        # always stored & reasoned about.
        Factory::Parrygg.event_state(state)
      end

      def event_entrants(provider_event_id:, game:, page:, cursor:)
        # Simulate a blank page after the first page to stop the loop, because
        # as of July 2026 parrygg doesn't currently paginate entrants.
        return [[], nil] if page > 1

        result = Api::Parrygg.with_retries(10) do
          Api::Parrygg.event_entrants(event_id: provider_event_id)
        end

        [result[:eventEntrants]]
      end

      def event_winner_entrant_id(provider_event_id:)
        result = Api::Parrygg.with_retries(10) do
          Api::Parrygg.event_placements(event_id: provider_event_id)
        end

        result[:results]&.first&.dig(:placement, :eventEntrant, :entrant, :id)
      end

      def sleep_time
        0.1
      end

    end
  end
end
