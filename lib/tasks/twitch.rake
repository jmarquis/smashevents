namespace :twitch do

  task sync_streams: [:environment] do
    Tournament
      .includes(:streams)
      .should_display
      .where('tournaments.start_at <= ?', Time.now + 12.hours)
      .where('tournaments.end_at >= ?', Time.now - 12.hours)
      .each do |tournament|
      next unless tournament.streams.any?
      next unless tournament.events.any? { |e| e.winner_entrant_id.blank? }

      Rails.logger.debug "Syncing Twitch streams for #{tournament.slug}..."

      # Collect all the tournament's Twitch streams...
      streams = tournament.streams.filter do |stream|
        stream.platform == Stream::PLATFORM_TWITCH
      end

      next unless streams.present?

      begin
        # ...fetch their statuses from Twitch in bulk...
        live_streams = Twitch::Gateway.streams(channels: streams.map(&:channel))

        # ...and update the tournament's streams with the results.
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
          # we're displaying events for. Notify when the stream goes live, or
          # when an already live stream switches games, since it may have
          # switched from a game we weren't displaying to one we are.
          went_live = stream.status != Stream::STATUS_LIVE
          changed_game = stream.game_name != stream_data[:game]
          should_notify = (went_live || changed_game) && tournament.events.where(game_slug: game.slug).any?(&:should_display?)

          stream.status = Stream::STATUS_LIVE
          stream.game_name = stream_data[:game]
          stream.title = stream_data[:title]
          stream.save!

          next unless should_notify

          Rails.logger.info "Sending stream live notification for #{tournament.slug} #{stream.game_name}: #{stream.channel}"

          Notification.send_notification(
            tournament,
            type: Notification::TYPE_STREAM_LIVE,
            platform: Notification::PLATFORM_DISCORD
          ) do |tournament|
            Discord::Gateway.stream_live(tournament:, stream:)
          end
        end

        # Broadcast changes if there were any.
        tournament.touch if streams.any?(&:saved_changes?)
      rescue Twitch::Error => e
        Rails.logger.error "Error syncing stream: #{e.message}"
      end
    end
  end

end
