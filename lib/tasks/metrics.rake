namespace :metrics do
  task report_model_stats: [:environment] do
    StatsD.gauge('model_counts.tournaments', Tournament.count)
    StatsD.gauge('model_counts.events', Event.count)
    StatsD.gauge('model_counts.entrants', Entrant.count)
    StatsD.gauge('model_counts.players', Player.count)
    StatsD.gauge('model_counts.player_subscriptions', PlayerSubscription.count)
  end
end
