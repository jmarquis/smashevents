namespace :tournaments do

  task sync: [:environment] do
    RETRIES_PER_FETCH = 5

    (1..3).each do |page|
      tournaments = []
      retries = 0

      loop do
        puts "Fetching page #{page} of tournaments..."
        tournaments = StartggClient.tournaments(batch_size: 10, page:)
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
      tournaments.each do |t|
        puts "Analyzing #{t.name}..."
        tournament = Tournament.from_startgg(t)
        puts "#{tournament.player_count} players."
        if tournament.interesting?
          puts 'Saved!'
          tournament.save
        end
      end

      sleep 1

    end
    puts "Done."
  end

end
