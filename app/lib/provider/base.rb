module Provider
  class Base
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

      def tournaments(page:, cursor:, after_date:, updated_after:)
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
