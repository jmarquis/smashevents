namespace :youtube do

  task fetch_stream_urls: [:environment] do
    Rails.logger.info 'Starting Youtube stream sync...'

    Tournament.where('start_at <= ?', Time.now + 1.day).where('end_at >= ?', Time.now - 1.day).each do |tournament|
      next unless tournament.should_display?

      streams = tournament.streams.where(platform: Stream::PLATFORM_YOUTUBE, youtube_channel_id: nil)
      next unless streams.any?

      Rails.logger.info "Syncing Youtube channel IDs for #{tournament.slug}..."

      streams = streams.to_a
      streams.each do |stream|
        stream.youtube_channel_id = Youtube::Gateway.channel_id(stream.channel)
        stream.save!
      end

      tournament.touch if streams.any?(&:saved_changes?)
    end
  end

end
