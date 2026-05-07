namespace :startgg do
  task sync: [:environment, 'startgg:sync_tournaments', 'startgg:sync_overrides', 'startgg:sync_entrants']

  task sync_tournaments: [:environment] do
    Provider::Startgg.sync_tournaments
  end

  task sync_overrides: [:environment] do
    Provider::Startgg.sync_overrides
  end

  task :sync_entrants, [:tournament_id] => [:environment] do |task, args|
    num_events = 0
    stats = {
      created: 0,
      updated: 0,
      deleted: 0
    }

    Rails.logger.info 'Starting entrant sync...'

    tournaments = args[:tournament_id].present? ? [Tournament.find(args[:tournament_id])] : Tournament.not_past.reasonable_duration

    tournaments.each do |tournament|
      unseeded_in_progress_events = tournament.events.in_progress.where(is_seeded: false)
      events = args[:tournament_id].present? ? tournament.events : tournament.events.should_sync_entrants

      [*unseeded_in_progress_events, *events].each do |event|
        stats = event.sync_entrants!.reduce(stats) do |stats, (key, total)|
          stats[key] += total
          stats
        end

        num_events += 1
        if num_events % 50 == 0
          Rails.logger.info "Scanned #{num_events} events so far..."
        end
      end
    end

    Rails.logger.info "Entrant sync complete. #{stats.to_json}"
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
