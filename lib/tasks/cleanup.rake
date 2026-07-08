namespace :cleanup do

  task delete_old_tournaments: [:environment] do
    Tournament
      .where('end_at < ?', 30.days.ago)
      .order(end_at: :asc)
      .find_each do |tournament|
        next if tournament.should_display?

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
