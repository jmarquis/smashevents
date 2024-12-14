namespace :youtube do

  task fetch_stream_urls: [:environment] do
    puts 'Starting Youtube stream sync...'

    Tournament.where('start_at <= ?', Time.now + 1.day).where('end_at >= ?', Time.now - 1.day).each do |tournament|
      next unless tournament.stream_data.present?
      next unless tournament.stream_data.filter { |stream| stream.with_indifferent_access[:source].downcase == Tournament::STREAM_SOURCE_YOUTUBE }.any?
      next unless tournament.should_display?

      puts "Syncing Youtube stream URLs for #{tournament.slug}..."

      tournament.stream_data = tournament.stream_data.map do |stream|
        stream = stream.with_indifferent_access

        if stream[:source].downcase == Tournament::STREAM_SOURCE_YOUTUBE && stream[:url].blank?
          url = Youtube.channel_url(stream[:name])
          stream[:url] = url if url.present?
        end

        stream
      end

      puts "#{tournament.slug}: #{tournament.changes}"
      tournament.save
    end
  end

end
