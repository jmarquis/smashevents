module Factory
  class Base
    class << self

      def factory(provider_name)
        case provider_name
        when Provider::Startgg::PROVIDER_NAME
          Factory::Startgg
        when Provider::Parrygg::PROVIDER_NAME
          Factory::Parrygg
        end
      end

      def tournament(data)
        raise NotImplementedError
      end

      def entrant(data, event:)
        raise NotImplementedError
      end

      def player(data, tag: nil)
        raise NotImplementedError
      end

    end
  end
end
