namespace :backfill do
  task provider_startgg: [:environment] do
    Tournament.find_each do |t|
      t.provider = Provider::Startgg::PROVIDER_NAME
      t.save!
    end

    TournamentOverride.find_each do |o|
      o.provider = Provider::Startgg::PROVIDER_NAME
      o.save!
    end

    Player.find_each do |p|
      p.provider = Provider::Startgg::PROVIDER_NAME
      p.save!
    end
  end
end
