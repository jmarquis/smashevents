module Provider
  class Parrygg < Base
    PROVIDER_NAME = 'parrygg'

    EVENT_STATE_UNSPECIFIED = 'EVENT_STATE_UNSPECIFIED'
    EVENT_STATE_PENDING = 'EVENT_STATE_PENDING'
    EVENT_STATE_READY = 'EVENT_STATE_READY'
    EVENT_STATE_IN_PROGRESS = 'EVENT_STATE_IN_PROGRESS'
    EVENT_STATE_COMPLETED = 'EVENT_STATE_COMPLETED'

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
        case state
        when EVENT_STATE_UNSPECIFIED
          nil
        when EVENT_STATE_PENDING
          Event::STATE_CREATED
        when EVENT_STATE_READY
          Event::STATE_READY
        when EVENT_STATE_IN_PROGRESS
          Event::STATE_ACTIVE
        when EVENT_STATE_COMPLETED
          Event::STATE_COMPLETED
        end
      end

      def event_entrants(provider_event_id:, game:, page:, cursor:)
        # Simulate a blank page after the first page to stop the loop, because
        # parrygg doesn't currently paginate entrants.
        return [[], nil] if page > 1

        result = Api::Parrygg.event_entrants(event_id: provider_event_id)
        [result[:eventEntrants]]
      end

      def sleep_time
        0.1
      end

    end
  end
end
