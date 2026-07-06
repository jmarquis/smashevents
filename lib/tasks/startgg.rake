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
    cursor_date = Rails.cache.read('startgg/past_tournaments_cursor_date') || Time.now

    last_tournament = Ingestor::Startgg.sync_tournaments(before_date: cursor_date, limit: 1000, sync_entrants: true)

    Rails.cache.write('startgg/past_tournaments_cursor_date', last_tournament.end_at + 1.hour, expires_in: 30.days) if last_tournament.present?
  end

end
