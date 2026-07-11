namespace :startgg do

  task sync: [:environment, 'startgg:sync_tournaments', 'startgg:sync_overrides', 'startgg:sync_entrants']

  task sync_tournaments: [:environment] do
    Ingestor::Startgg.sync_tournaments
  end

  task sync_overrides: [:environment] do
    Ingestor::Startgg.sync_overrides
  end

  task sync_entrants: [:environment] do
    Ingestor::Startgg.sync_entrants
  end

  task sync_sets: [:environment] do
    Ingestor::Startgg.sync_sets
  end

  task sync_past_tournaments: [:environment] do
    # This hits the startgg API a lot so let's only do it when we're not polling
    # for sets and stuff for in-progress tournaments.
    return if Tournament.where(provider: Provider::Startgg::PROVIDER_NAME).should_display.in_progress.any?

    cursor_date = Rails.cache.read('startgg/past_tournaments_cursor_date') || Time.now

    Ingestor::Startgg.sync_tournaments(before_date: cursor_date + 1.hour, limit: 100, sync_entrants: true) do |tournament|
      Rails.cache.write('startgg/past_tournaments_cursor_date', tournament.end_at, expires_in: 30.days)
      StatsD.gauge('startgg.past_tournaments_cursor_date', tournament.end_at.to_i)
    end
  end

end
