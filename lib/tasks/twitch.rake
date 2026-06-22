namespace :twitch do

  task sync_streams: [:environment] do
    Tournament
      .should_display
      .where('tournaments.start_at <= ?', Time.now + 12.hours)
      .where('tournaments.end_at >= ?', Time.now - 12.hours)
      .each do |tournament|
      next unless tournament.stream_data.present?
      next unless tournament.events.any? { |e| e.winner_entrant_id.blank? }

      Rails.logger.debug "Syncing Twitch streams for #{tournament.slug}..."

      streams = tournament.stream_data.reduce([]) do |streams, stream|
        stream = stream.with_indifferent_access
        streams += [stream[:name]] if stream[:source]&.downcase == Tournament::STREAM_SOURCE_TWITCH

        streams
      end

      next unless streams.present?

      begin
        live_streams = Api::Twitch.streams(streams:)
        tournament.stream_data = tournament.stream_data.map do |stream|
          stream = stream.with_indifferent_access
          game = Game.find_by(twitch_name: live_streams[stream[:name].downcase][:game]) if stream[:name].downcase.in?(live_streams)
          potential_events = tournament.events.where(game_slug: game&.slug)

          if stream[:source].downcase == Tournament::STREAM_SOURCE_TWITCH
            && game.present?
            && potential_events.any?(&:should_display?)

            should_notify = stream[:status] != Tournament::STREAM_STATUS_LIVE

            stream[:status] = Tournament::STREAM_STATUS_LIVE
            stream[:game] = live_streams[stream[:name].downcase][:game]
            stream[:title] = live_streams[stream[:name].downcase][:title]

            if should_notify
              Rails.logger.info "Sending stream live notification for #{tournament.slug} #{stream[:game]}: #{stream[:name]}"

              Notification.send_notification(
                tournament,
                type: Notification::TYPE_STREAM_LIVE,
                platform: Notification::PLATFORM_DISCORD
              ) do |tournament|
                Api::Discord.stream_live(tournament:, stream:)
              end
            end
          else
            stream.delete(:status)
            stream.delete(:game)
            stream.delete(:title)
          end

          stream
        end

        if tournament.changed?
          Rails.logger.info "#{tournament.slug}: #{tournament.changes}"
          tournament.save
        end
      rescue Twitch::Error => e
        Rails.logger.error "Error syncing stream: #{e.message}"
      end
    end
  end

end
