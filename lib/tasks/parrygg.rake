namespace :parrygg do

  task sync: [:environment, 'parrygg:sync_tournaments', 'parrygg:sync_overrides', 'parrygg:sync_entrants', 'parrygg:sync_streams']

  task sync_tournaments: [:environment] do
    Parrygg::Ingestor.sync_tournaments
  end

  task sync_overrides: [:environment] do
    Parrygg::Ingestor.sync_overrides
  end

  task sync_entrants: [:environment] do
    Parrygg::Ingestor.sync_entrants
  end

  task sync_streams: [:environment] do
    Parrygg::Ingestor.sync_streams
  end

  task sync_sets: [:environment] do
    Parrygg::Ingestor.sync_sets
  end

end
