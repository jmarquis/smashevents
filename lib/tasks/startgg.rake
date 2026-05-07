namespace :startgg do
  task sync: [:environment, 'startgg:sync_tournaments', 'startgg:sync_overrides', 'startgg:sync_entrants']

  task sync_tournaments: [:environment] do
    Provider::Startgg.sync_tournaments
  end

  task sync_overrides: [:environment] do
    Provider::Startgg.sync_overrides
  end

  task sync_entrants: [:environment] do
    Provider::Startgg.sync_entrants
  end

  task scan_sets: [:environment] do
    Tournament.should_display.in_progress.each do |tournament|
      tournament.events.each do |event|
        event.sync_state!
      end

      tournament.events.in_progress.each do |event|
        event.sync_sets!
      end
    end
  end

  private

  def updated_log(tournament, events)
    tournament_changes = tournament.saved_changes.reject { |k| k == 'updated_at' }
    Rails.logger.info "~ #{tournament.slug}: #{tournament_changes}"
    events.each do |event|
      event_changes = event.saved_changes.reject { |k| k == 'updated_at' }
      next if event_changes.blank?

      Rails.logger.info "  ~ #{event.game.slug.upcase}: #{event_changes}"
    end
  end

  def puts_dev(msg)
    Rails.logger.info(msg) if Rails.env.development?
  end
end
