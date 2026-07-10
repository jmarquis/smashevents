class Turbo::StreamsChannel
  ACTIVE_SUBSCRIPTIONS = Concurrent::AtomicFixnum.new(0)
  SUBSCRIPTIONS_PER_CONSUMER = {}
  SUBSCRIPTIONS_PER_CONSUMER_MUTEX = Mutex.new

  after_subscribe :report_subscribed_gauge, unless: :subscription_rejected?
  after_unsubscribe :report_unsubscribed_gauge, unless: :subscription_rejected?

  private

  def report_subscribed_gauge
    StatsD.gauge('turbo_streams.subscriptions', ACTIVE_SUBSCRIPTIONS.increment)

    consumer_count = SUBSCRIPTIONS_PER_CONSUMER_MUTEX.synchronize do
      SUBSCRIPTIONS_PER_CONSUMER[connection] = (SUBSCRIPTIONS_PER_CONSUMER[connection] || 0) + 1
      SUBSCRIPTIONS_PER_CONSUMER.size
    end
    StatsD.gauge('turbo_streams.consumers', consumer_count)
  end

  def report_unsubscribed_gauge
    StatsD.gauge('turbo_streams.subscriptions', ACTIVE_SUBSCRIPTIONS.decrement)

    consumer_count = SUBSCRIPTIONS_PER_CONSUMER_MUTEX.synchronize do
      remaining = (SUBSCRIPTIONS_PER_CONSUMER[connection] || 1) - 1
      if remaining <= 0
        SUBSCRIPTIONS_PER_CONSUMER.delete(connection)
      else
        SUBSCRIPTIONS_PER_CONSUMER[connection] = remaining
      end
      SUBSCRIPTIONS_PER_CONSUMER.size
    end
    StatsD.gauge('turbo_streams.consumers', consumer_count)
  end

  def transmit(data, via: nil)
    StatsD.increment('turbo_streams.transmit') if via&.start_with?('streamed from')
    super
  end
end
