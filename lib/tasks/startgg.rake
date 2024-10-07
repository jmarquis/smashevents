namespace :startgg do
  task sync: [:environment, 'startgg:sync_tournaments', 'startgg:sync_overrides', 'startgg:sync_entrants']

  task sync_tournaments: [:environment] do
    num_analyzed = 0
    num_imported = 0
    num_updated = 0

    (1..100).each do |page|
      tournaments = with_retries(5) do
        puts "Fetching page #{page} of tournaments..."
        Startgg.tournaments(batch_size: 50, page:, after_date: Time.now - 7.days)
      end

      puts "#{tournaments.count} tournaments found. Analyzing..."
      num_analyzed += tournaments.count
      break if tournaments.count.zero?

      tournaments.each do |data|
        tournament, events = Tournament.from_startgg(data)

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
          event_blurbs = tournament.events.map { |event| "#{event.game}: #{event.player_count}" }
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

      tournament, events = Tournament.from_startgg(data)

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
        event_blurbs = tournament.events.map { |event| "#{event.game}: #{event.player_count}" }
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

  task sync_entrants: [:environment] do
    num_events = 0

    puts 'Fetching event entrants...'

    Tournament.upcoming.each do |tournament|
      tournament.events.each do |event|
        featured_players = []
        entrants = []

        # Get all the entrants, 1 chunk at a time
        (1..100).each do |page|
          event_entrants = with_retries(5) do
            Startgg.event_entrants(
              id: event.startgg_id,
              game: Game.by_slug(event.game),
              batch_size: 100,
              page:
            )
          end

          # Respect startgg's rate limits...
          sleep 1

          # This means the tournament was probably deleted.
          if event_entrants.nil?
            puts 'Tournament not found. Deleting...'
            StatsD.increment('startgg.tournament_deleted')
            tournament.destroy
            break
          end

          # This means there are no available entrants.
          break if event_entrants.count.zero?

          entrants = [*entrants, *event_entrants]

          # If we don't have a full batch, this is the last page.
          break if event_entrants.count != 100
        end

        break if tournament.destroyed?

        # First see if the event is seeded
        entrants.each do |entrant|
          if entrant.initial_seed_num.present? && entrant.initial_seed_num <= 10
            featured_players[entrant.initial_seed_num - 1] = entrant.participants[0].player.gamer_tag
          end
        end

        # Otherwise try to use rankings
        rankings_key = Game.by_slug(event.game).rankings_key
        rankings_regex = Game.by_slug(event.game).rankings_regex
        ranked_entrants = entrants.filter do |entrant|
          entrant.participants[0]&.player&.send(rankings_key)&.filter do |ranking|
            ranking.title&.match(rankings_regex)
          end.present?
        end

        ranked_entrants = ranked_entrants.sort_by do |entrant|
          entrant.participants[0]&.player&.send(rankings_key)&.filter do |ranking|
            ranking.title&.match(rankings_regex)
          end&.[](0)&.rank
        end

        if featured_players.empty?
          ranked_entrants.each do |entrant|
            featured_players << entrant.participants[0].player.gamer_tag
            break if featured_players.count == 10
          end
        end

        event.featured_players = featured_players
        event.ranked_player_count = ranked_entrants.count
        event.save

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
    rescue Graphlient::Errors::ExecutionError, Graphlient::Errors::FaradayServerError => e
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

      puts "  ~ #{event.game.upcase}: #{event_changes}"
    end
  end
end
