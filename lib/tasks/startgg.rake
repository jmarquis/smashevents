namespace :startgg do

  task sync: [:environment, 'startgg:sync_tournaments', 'startgg:sync_overrides', 'startgg:sync_entrants']

  task sync_tournaments: [:environment] do
    analyzed = 0
    added = []
    updated = []

    (1..100).each do |page|
      tournaments = with_retries(5) do
        puts "Fetching page #{page} of tournaments..."
        StartggClient.tournaments(batch_size: 100, page:)
      end

      puts "#{tournaments.count} tournaments found."
      analyzed += tournaments.count
      break if tournaments.count.zero?

      tournaments.each do |data|
        puts "Analyzing #{data.name}..."
        tournament, any_events_changed = Tournament.from_startgg(data)

        tournament.events.each do |event|
          puts "#{event.game.upcase}: #{event.player_count || 0} players"
        end

        next unless tournament.interesting?

        if tournament.persisted?
          if tournament.changed? || any_events_changed
            tournament.save
            updated << tournament
            msg = 'Updated!'
          else
            msg = 'No updates found.'
          end
        else
          tournament.save
          added << tournament.slug
          msg = 'Imported!'
        end

        puts msg
      end

      sleep 1

    end

    puts '----------------------------------'
    puts "Analyzed: #{analyzed}"
    puts "Imported: #{added.count}"
    added.each { |t| puts "+ #{t}" }
    puts "Updated: #{updated.count}"
    updated.each do |t|
      changes = t.saved_changes.reject { |k| k == 'updated_at' }
      puts "~ #{t.slug}: #{changes}"
      t.events.each do |e|
        changes = e.saved_changes.reject { |k| k == 'updated_at' }
        next if changes.empty?
        puts "~ #{t.slug} / #{e.game}: #{changes}"
      end
    end
  end

  task sync_overrides: [:environment] do
    analyzed = 0
    added = []
    updated = []
    deleted = []

    TournamentOverride.all.each do |override|

      if !override.include
        tournament = Tournament.find_by(slug: override.slug)
        if tournament.present?
          tournament.destroy
          deleted << tournament.slug
        end
      else
        data = with_retries(5) do
          puts "Fetching tournament #{override.slug}..."
          StartggClient.tournament(slug: override.slug)
        end

        puts "Analyzing #{data.name}..."
        tournament, any_events_changed = Tournament.from_startgg(data)

        tournament.events.each do |event|
          puts "#{event.game.upcase}: #{event.player_count || 0} players"
        end

        if tournament.persisted?
          if tournament.changed? || any_events_changed
            tournament.save
            updated << tournament
            msg = 'Updated!'
          else
            msg = 'No updates found.'
          end
        else
          tournament.save
          added << tournament.slug
          msg = 'Imported!'
        end

        puts msg
        sleep 1

      end

    end

    puts '----------------------------------'
    puts "Analyzed: #{analyzed}"
    puts "Imported: #{added.count}"
    added.each { |t| puts "+ #{t}" }
    puts "Updated: #{updated.count}"
    updated.each do |t|
      changes = t.saved_changes.reject { |k| k == 'updated_at' }
      puts "~ #{t.slug}: #{changes}"
      t.events.each do |e|
        changes = e.saved_changes.reject { |k| k == 'updated_at' }
        next if changes.empty?
        puts "~ #{t.slug} / #{e.game}: #{changes}"
      end
    end
    puts "Deleted: #{deleted.count}"
    deleted.each { |t| puts "- #{t}" }
  end

  task sync_entrants: [:environment] do
    analyzed = 0
    added = []
    updated = []
    deleted = []

    Tournament.upcoming.each do |tournament|

      tournament.events.each do |event|
        featured_players = []
        entrants = []

        # Get all the entrants, 1 chunk at a time
        (1..100).each do |page|
          event_entrants = with_retries(5) do
            puts "Fetching #{event.game} entrants for #{tournament.name} (#{page})..."
            StartggClient.event_entrants(id: event.startgg_id, batch_size: 100, page:)
          end

          puts "Found #{event_entrants.count} entrants."

          # We get 0 back if there are no more past this page
          break if event_entrants.count.zero?

          entrants = [*entrants, *event_entrants]

          sleep 1
        end

        # First see if the event is seeded
        entrants.each do |entrant|
          if entrant.initial_seed_num.present? && entrant.initial_seed_num <= 10
            featured_players[entrant.initial_seed_num - 1] = entrant.participants[0].player.gamer_tag
          end
        end

        if featured_players.any?
          puts "Top seeds: #{featured_players.join(', ')}"
        else
          # Otherwise try to use rankings
          rankings_key = Game.by_startgg_id(game_id).rankings_key
          rankings_regex = Game.by_startgg_id(game_id).rankings_regex
          ranked_entrants = entrants.filter do |entrant|
            entrant.participants[0]&.player&.send(rankings_key)&.filter{ |ranking| ranking.title&.match(rankings_regex) }.present?
          end

          ranked_entrants = ranked_entrants.sort_by { |entrant| entrant.participants[0]&.player&.send(rankings_key)&.filter{ |ranking| ranking.title&.match(rankings_regex) }[0].rank }

          ranked_entrants.each do |entrant|
            featured_players << entrant.participants[0].player.gamer_tag
            break if featured_players.count == 10
          end

          if featured_players.any?
            puts "Ranked players: #{featured_players.join(', ')}"
          end
        end

        if featured_players.empty?
          puts 'Not enough player data to determine featured players!'
        end

        event.featured_players = featured_players
        event.save
      end

    end

  end

  private

  def with_retries(num_retries)
    retries = 0
    result = nil

    loop do
      result = yield
      break
    rescue Graphlient::Errors::ExecutionError, Graphlient::Errors::FaradayServerError => e
      if retries < num_retries
        puts "Transient error communicating with startgg, will retry: #{e.message}"
        retries += 1
        sleep 1
        next
      else
        puts "Retry threshold exceeded, exiting: #{e.message}"
        raise e
      end
    rescue => e
      puts "Unexpected error communicating with startgg: #{e.message}"
      raise e
    end

    result
  end

end
