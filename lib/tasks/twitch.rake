namespace :twitch do

  task sync_streams: [:environment] do
    Tournament.where('start_at <= ?', Time.now + 6.hours).where('end_at >= ?', Time.now - 6.hours).each do |tournament|
      next unless tournament.stream_data.present?

      puts "Syncing streams for #{tournament.slug}..."

      streams = tournament.stream_data.reduce([]) do |streams, stream|
        stream = stream.with_indifferent_access
        next unless stream[:source]&.upcase == 'TWITCH'

        streams + [stream[:name]]
      end

      next unless streams.present?

      live_streams = TwitchService.live_streams(streams:).map(&:upcase)
      tournament.stream_data = tournament.stream_data.map do |stream|
        stream = stream.with_indifferent_access

        if stream[:source].upcase == 'TWITCH'
          stream[:status] = stream[:name].upcase.in?(live_streams) ? TwitchService::STATUS_LIVE : nil
        end

        stream
      end

      puts "#{tournament.slug}: #{tournament.changes}"
      tournament.save
    end
  end

end
