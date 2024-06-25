namespace :tournaments do

  task sync: [:environment] do
    RETRIES_PER_FETCH = 5
    analyzed = 0
    added = 0
    updated = 0

    (1..10).each do |page|
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

      tournaments.each do |data|
        puts "Analyzing #{data.name}..."
        tournament = Tournament.from_startgg(data)
        puts "#{tournament.player_count} players."
        if tournament.interesting?
          if tournament.persisted?
            msg = 'Updated!'
            updated += 1
          else
            msg = 'Imported!'
            added += 1
          end
          tournament.save
          puts msg
        end
      end

      sleep 1

    end
    puts "Done."
  end

end
