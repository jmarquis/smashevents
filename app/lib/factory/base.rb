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

      def entrant(data)
        raise NotImplementedError
      end

      def player(data)
        raise NotImplementedError
      end

    end
  end
end
