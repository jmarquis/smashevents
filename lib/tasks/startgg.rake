namespace :startgg do
  task sync: [:environment, 'startgg:sync_tournaments', 'startgg:sync_overrides', 'startgg:sync_entrants']

  task sync_tournaments: [:environment] do
    num_analyzed = 0
    num_imported = 0
    num_updated = 0

    puts 'Starting tournament sync...'

    (1..100).each do |page|
      tournaments = with_retries(5) do
        puts "Fetching page #{page} of tournaments..."
        Startgg.tournaments(batch_size: 40, page:, after_date: Time.now - 7.days)
      end

      puts "#{tournaments.count} tournaments found. Analyzing..."
      num_analyzed += tournaments.count
      break if tournaments.count.zero?

      tournaments.each do |data|
        tournament, events = Tournament.from_startgg_tournament(data)

        next if events.blank?
        next if tournament.exclude?
        next unless events.any?(&:should_ingest?) || tournament.should_ingest?

        if tournament.persisted?
          if tournament.changed? || events.any?(&:changed?)
            tournament.save
            events.each(&:save)

            StatsD.increment('startgg.tournament_updated')
            updated_log(tournament, events)
            num_updated += 1
          end
        else
          tournament.save

          StatsD.increment('startgg.tournament_added')
          event_blurbs = tournament.events.map { |event| "#{event.game.slug}: #{event.player_count}" }
          puts "+ #{tournament.slug}: #{event_blurbs.join(', ')}"
        end
      end

      sleep 1
    end

    puts '----------------------------------'
    puts "Analyzed: #{num_analyzed}"
    puts "Imported: #{num_imported}"
    puts "Updated: #{num_updated}"
  end

  task sync_overrides: [:environment] do
    num_analyzed = 0
    num_imported = 0
    num_updated = 0
    num_deleted = 0

    puts 'Starting override sync...'

    TournamentOverride.all.each do |override|
      if !override.include
        tournament = Tournament.find_by(slug: override.slug)
        if tournament.present?
          puts "- #{tournament.slug}"

          StatsD.increment('startgg.tournament_deleted')
          tournament.destroy
          num_deleted += 1
        end

        next
      end

      tournament = Tournament.find_by(slug: override.slug)
      next if tournament.present? && tournament.past?

      num_analyzed += 1

      data = with_retries(5) do
        puts "Fetching tournament #{override.slug}..."
        Startgg.tournament(slug: override.slug)
      end

      tournament, events = Tournament.from_startgg_tournament(data)

      if tournament.persisted?
        if tournament.changed? || events.any?(&:changed?)
          tournament.save

          StatsD.increment('startgg.tournament_updated')
          updated_log(tournament, events)
          num_updated += 1
        end
      else
        tournament.save

        StatsD.increment('startgg.tournament_added')
        event_blurbs = tournament.events.map { |event| "#{event.game.slug}: #{event.player_count}" }
        puts "+ #{tournament.slug}: #{event_blurbs.join(',')}"
        num_imported += 1
      end

      sleep 1
    end

    puts '----------------------------------'
    puts "Analyzed: #{num_analyzed}"
    puts "Imported: #{num_imported}"
    puts "Updated: #{num_updated}"
    puts "Deleted: #{num_deleted}"
  end

  task :sync_entrants, [:tournament_id] => [:environment] do |task, args|
    num_events = 0

    puts 'Starting entrant sync...'

    tournaments = args[:tournament_id].present? ? [Tournament.find(args[:tournament_id])] : Tournament.upcoming

    tournaments.each do |tournament|
      events = args[:tournament_id].present? ? tournament.events : tournament.events.should_sync

      events.each do |event|
        event.sync_entrants

        num_events += 1
        if num_events % 50 == 0
          puts "Scanned #{num_events} events so far..."
        end
      end
    end

    puts 'Entrant sync complete.'
  end

  private

  def with_retries(num_retries)
    retries = 0
    result = nil

    loop do
      result = yield
      break
    rescue Graphlient::Errors::ExecutionError,
      Graphlient::Errors::FaradayServerError,
      Graphlient::Errors::ConnectionFailedError,
      Graphlient::Errors::TimeoutError,
      Faraday::ParsingError,
      OpenSSL::SSL::SSLError => e
      StatsD.increment('startgg.request_error')

      if retries < num_retries
        puts "Transient error communicating with startgg, will retry: #{e.message}"
        retries += 1
        sleep 5 * retries
        next
      else
        puts "Retry threshold exceeded, exiting: #{e.message}"
        raise e
      end
    rescue StandardError => e
      puts "Unexpected error communicating with startgg: #{e.message}"
      raise e
    end

    result
  end

  def updated_log(tournament, events)
    tournament_changes = tournament.saved_changes.reject { |k| k == 'updated_at' }
    puts "~ #{tournament.slug}: #{tournament_changes}"
    events.each do |event|
      event_changes = event.saved_changes.reject { |k| k == 'updated_at' }
      next if event_changes.blank?

      puts "  ~ #{event.game.slug.upcase}: #{event_changes}"
    end
  end

  def puts_dev(msg)
    puts msg if Rails.env.development?
  end
end
