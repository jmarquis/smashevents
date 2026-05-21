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

end
