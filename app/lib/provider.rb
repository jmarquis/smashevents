class Provider
  SORT_ORDER_OLDEST_FIRST = 'oldest_first'
  SORT_ORDER_NEWEST_FIRST = 'newest_first'

  class << self

    def provider(name)
      case name
      when Startgg::Provider::PROVIDER_NAME
        Startgg::Provider
      when Parrygg::Provider::PROVIDER_NAME
        Parrygg::Provider
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

    def in_progress_sets(provider_event_id:, batch_size:, page:)
      raise NotImplementedError
    end

    def completed_sets(provider_event_id:, batch_size:, page:, updated_after:)
      raise NotImplementedError
    end

    def sleep_time
      1
    end

  end
end
