namespace :parrygg do

  task sync: [:environment, 'parrygg:sync_tournaments', 'parrygg:sync_overrides', 'parrygg:sync_entrants']

  task sync_tournaments: [:environment] do
    Ingestor::Parrygg.sync_tournaments
  end

  task sync_overrides: [:environment] do
    Ingestor::Parrygg.sync_overrides
  end

  task sync_entrants: [:environment] do
    Ingestor::Parrygg.sync_entrants
  end

  task scan_sets: [:environment] do
    Ingestor::Parrygg.scan_sets
  end

end
