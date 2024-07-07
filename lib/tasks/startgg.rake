namespace :startgg do

  task sync: [:environment, 'startgg:sync_tournaments', 'startgg:sync_overrides', 'startgg:sync_entrants']

  task sync_tournaments: [:environment] do
    RETRIES_PER_FETCH = 5
    analyzed = 0
    added = []
    updated = []

    (1..100).each do |page|
      tournaments = []
      retries = 0

      loop do
        puts "Fetching page #{page} of tournaments..."
        tournaments = StartggClient.tournaments(batch_size: 100, page:)
        break
      rescue Graphlient::Errors::ExecutionError => e
        if retries < RETRIES_PER_FETCH
          puts "Transient error fetching tournaments, will retry: #{e.message}"
          retries += 1
          sleep 1
          next
        else
          puts "Retry threshold exceeded, exiting: #{e.message}"
          raise e
        end
      rescue => e
        puts "Unexpected error fetching tournaments: #{e.message}"
        raise e
      end

      puts "#{tournaments.count} tournaments found."
      analyzed += tournaments.count
      break if tournaments.count.zero?

      tournaments.each do |data|
        puts "Analyzing #{data.name}..."
        tournament = Tournament.from_startgg(data)
        puts "#{tournament.melee_player_count} Melee players, #{tournament.ultimate_player_count} Ultimate players."
        next unless tournament.interesting?

        if tournament.persisted?
          if tournament.changed?
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
    end
  end

  task sync_overrides: [:environment] do
    RETRIES_PER_FETCH = 5
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
        data = nil
        retries = 0

        loop do
          puts "Fetching tournament #{override.slug}..."
          data = StartggClient.tournament(slug: override.slug)
          break
        rescue Graphlient::Errors::ExecutionError, Graphlient::Errors::FaradayServerError => e
          if retries < RETRIES_PER_FETCH
            puts "Transient error fetching tournament, will retry: #{e.message}"
            retries += 1
            sleep 1
            next
          else
            puts "Retry threshold exceeded, exiting: #{e.message}"
            raise e
          end
        rescue => e
          puts "Unexpected error fetching tournament: #{e.message}"
          raise e
        end

        puts "Analyzing #{data.name}..."
        tournament = Tournament.from_startgg(data)
        puts "#{tournament.melee_player_count} Melee players, #{tournament.ultimate_player_count} Ultimate players."

        if tournament.persisted?
          if tournament.changed?
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

      events = with_retries(5) do
        puts "Fetching tournament #{tournament.slug}..."
        StartggClient.tournament_events(slug: tournament.slug)
      end

      biggest_events = {
        Tournament::MELEE_ID => nil,
        Tournament::ULTIMATE_ID => nil
      }

      events.each do |event|
        puts "#{event.num_entrants || 0} entrants in #{event.name} (#{event.videogame.id.to_i == Tournament::MELEE_ID ? 'Melee' : 'Ultimate'})"
        biggest_events[event.videogame.id.to_i] = event if event.num_entrants.present? && event.num_entrants > (biggest_events[event.videogame.id.to_i]&.num_entrants || 0)
      end

      present_events = biggest_events.filter{ |game_id, event| event.present? }
      featured_players = present_events.merge(present_events) do |game_id, event|
        players = []
        entrants = []

        # Get all the entrants, 1 chunk at a time
        (1..100).each do |page|
          event_entrants = with_retries(5) do
            puts "Fetching entrants for #{event.name} (#{page})..."
            StartggClient.event_entrants(id: event.id, batch_size: 100, page:)
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
            players[entrant.initial_seed_num - 1] = entrant.participants[0].player.gamer_tag
          end
        end

        if players.any?
          puts "Top seeds: #{players.join(', ')}"
        else
          # Otherwise try to use rankings
          rankings_key = StartggClient::RANKINGS_KEY_MAP[game_id]
          rankings_regex = StartggClient::RANKINGS_REGEX_MAP[game_id]
          ranked_entrants = entrants.filter do |entrant|
            entrant.participants[0]&.player&.send(rankings_key)&.filter{ |ranking| ranking.title&.match(rankings_regex) }.present?
          end

          ranked_entrants = ranked_entrants.sort_by { |entrant| entrant.participants[0]&.player&.send(rankings_key)&.filter{ |ranking| ranking.title&.match(rankings_regex) }[0].rank }

          ranked_entrants.each do |entrant|
            players << entrant.participants[0].player.gamer_tag
            break if players.count == 10
          end

          if players.any?
            puts "Ranked players: #{players.join(', ')}"
          end
        end

        if players.empty?
          puts 'Not enough player data!'
        end

        players
      end

      tournament.melee_featured_players = featured_players[Tournament::MELEE_ID]
      tournament.ultimate_featured_players = featured_players[Tournament::ULTIMATE_ID]

      tournament.save

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
