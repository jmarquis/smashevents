namespace :tournaments do

  task sync: [:environment] do
    RETRIES_PER_FETCH = 5
    analyzed = 0
    added = []
    updated = []

    (1..50).each do |page|
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
    RETRIES_PER_FETCH = 5
    analyzed = 0
    added = []
    updated = []
    deleted = []

    Tournament.upcoming.each do |tournament|
      events = []
      retries = 0

      loop do
        puts "Fetching tournament #{tournament.slug}..."
        events = StartggClient.tournament_events_with_entrants(slug: tournament.slug)
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

      events.each do |event|
        puts "Analyzing #{event.name}..."
      end

    end

  end

end
