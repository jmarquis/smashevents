namespace :cleanup do

  task delete_old_tournaments: [:environment] do
    tournaments = Tournament
      .where('end_at < ?', Date.today - 30.days)
      .order(created_at: :asc)
      .filter { |t| !t.should_display? }

    tournaments.each do |tournament|
      puts "Deleting #{tournament.slug}..."
      tournament.destroy!
    end
  end
  
end
