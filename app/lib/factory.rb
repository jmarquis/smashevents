class Factory
  class << self

    def factory(provider_name)
      case provider_name
      when Startgg::Provider::PROVIDER_NAME
        Startgg::Factory
      when Parrygg::Provider::PROVIDER_NAME
        Parrygg::Factory
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
