namespace :twitch do

  task sync_streams: [:environment] do
    puts 'Starting Twitch stream sync...'

    Tournament.where('start_at <= ?', Time.now + 12.hours).where('end_at >= ?', Time.now - 12.hours).each do |tournament|
      next unless tournament.stream_data.present?
      next unless tournament.should_display?

      puts "Syncing streams for #{tournament.slug}..."

      streams = tournament.stream_data.reduce([]) do |streams, stream|
        stream = stream.with_indifferent_access
        next unless stream[:source]&.downcase == Tournament::STREAM_SOURCE_TWITCH

        streams + [stream[:name]]
      end

      next unless streams.present?

      begin
        live_streams = Twitchy.live_streams(streams:)
        tournament.stream_data = tournament.stream_data.map do |stream|
          stream = stream.with_indifferent_access

          if stream[:source].downcase == Tournament::STREAM_SOURCE_TWITCH && stream[:name].downcase.in?(live_streams)
            should_notify = stream[:status] != Tournament::STREAM_STATUS_LIVE

            stream[:status] = Tournament::STREAM_STATUS_LIVE
            stream[:game] = live_streams[stream[:name].downcase][:game]
            stream[:title] = live_streams[stream[:name].downcase][:title]

            Discord.stream_live(tournament:, stream:) if should_notify
          else
            stream.delete(:status)
            stream.delete(:game)
            stream.delete(:title)
          end

          stream
        end

        puts "#{tournament.slug}: #{tournament.changes}"
        tournament.save
      rescue Twitch::APIError => e
        puts "Error syncing stream: #{e.message}"
      end
    end
  end

end
