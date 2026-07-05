module Provider
  class Base
    SORT_ORDER_OLDEST_FIRST = 'oldest_first'
    SORT_ORDER_NEWEST_FIRST = 'newest_first'

    class << self

      def provider(name)
        case name
        when Provider::Startgg::PROVIDER_NAME
          Provider::Startgg
        when Provider::Parrygg::PROVIDER_NAME
          Provider::Parrygg
        end
      end

      ##########################################

      def base_url
        raise NotImplementedError
      end

      def tournaments(
        page:,
        cursor:,
        before_date: nil,
        after_date: nil,
        updated_after: nil,
        sort_order: nil
      )
        raise NotImplementedError
      end

      def tournament(slug:)
        raise NotImplementedError
      end

      def event_state(provider_event_id:)
        raise NotImplementedError
      end

      def event_entrants(provider_event_id:, game:, page:, cursor:)
        raise NotImplementedError
      end

      def sleep_time
        1
      end

    end
  end
end
