namespace :twitch do

  task sync_streams: [:environment] do
    Tournament
      .includes(:streams)
      .should_display
      .where('tournaments.start_at <= ?', Time.now + 12.hours)
      .where('tournaments.end_at >= ?', Time.now - 12.hours)
      .each do |tournament|
      # TODO: next unless tournament.streams.any?
      next unless tournament.stream_data.present?
      next unless tournament.events.any? { |e| e.winner_entrant_id.blank? }

      Rails.logger.debug "Syncing Twitch streams for #{tournament.slug}..."

      # Collect all the tournament's Twitch streams...
      channels = tournament.stream_data.reduce([]) do |channels, stream|
        stream = stream.with_indifferent_access
        channels += [stream[:name]] if stream[:source]&.downcase == Tournament::STREAM_SOURCE_TWITCH

        channels
      end

      streams = tournament.streams.filter do |stream|
        stream.source.downcase == Tournament::STREAM_SOURCE_TWITCH
      end

      next unless channels.present?

      begin
        # ...fetch their statuses from Twitch in bulk...
        live_streams = Twitch::Gateway.streams(channels:)
        # TODO: live_streams = Twitch::Gateway.streams(channels: streams.map(&:channel))

        # ...and update the tournament's stream data with the results.
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
                Discord::Gateway.stream_live(tournament:, stream:)
              end
            end
          else
            stream.delete(:status)
            stream.delete(:game)
            stream.delete(:title)
          end

          stream
        end

        streams.each do |stream|
          unless stream.channel.downcase.in?(live_streams)
            stream.update!(
              status: nil,
              game_name: nil,
              title: nil
            )
            next
          end

          stream_data = live_streams[stream.channel.downcase]

          game = Game.find_by(twitch_name: stream_data[:game])
          if game.blank?
            stream.update!(
              status: nil,
              game_name: nil,
              title: nil
            )
            next
          end

          # We only want to notify about streams that correspond to games that
          # we're displaying events for.
          should_notify = stream.status != Stream::STATUS_LIVE && tournament.events.where(game_slug: game.slug).any?(&:should_display?)

          stream.status = Stream::STATUS_LIVE
          stream.game_name = stream_data[:game]
          stream.title = stream_data[:title]
          stream.save!

          next # TODO: unless should_notify

          Rails.logger.info "Sending stream live notification for #{tournament.slug} #{stream[:game]}: #{stream[:name]}"

          Notification.send_notification(
            tournament,
            type: Notification::TYPE_STREAM_LIVE,
            platform: Notification::PLATFORM_DISCORD
          ) do |tournament|
            # TODO: Update this method to accept a Stream
            Discord::Gateway.stream_live(tournament:, stream:)
          end
        end

        # Broadcast changes if there were any.
        tournament.touch if streams.any(&:saved_changes?)

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
