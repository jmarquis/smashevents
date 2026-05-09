namespace :cleanup do

  task delete_old_tournaments: [:environment] do
    Tournament
      .where('end_at < ?', Date.today - 30.days)
      .order(created_at: :asc)
      .filter { |t| !t.should_display? }
      .each do |tournament|
        Rails.logger.info "Deleting tournament #{tournament.slug}..."
        tournament.destroy!
      end
  end

  task delete_orphaned_players: [:environment] do
    Player.where.missing(:entrants).find_each do |player|
      Rails.logger.info "Deleting orphaned player #{player.tag}"
      player.destroy!
    end
  end
  
end
