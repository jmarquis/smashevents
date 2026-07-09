class Turbo::StreamsChannel
  ACTIVE_SUBSCRIPTIONS = Concurrent::AtomicFixnum.new(0)

  after_subscribe :report_subscribed_gauge, unless: :subscription_rejected?
  after_unsubscribe :report_unsubscribed_gauge, unless: :subscription_rejected?

  private

  def report_subscribed_gauge
    StatsD.gauge('turbo_streams.subscriptions', ACTIVE_SUBSCRIPTIONS.increment)
  end

  def report_unsubscribed_gauge
    StatsD.gauge('turbo_streams.subscriptions', ACTIVE_SUBSCRIPTIONS.decrement)
  end
end
