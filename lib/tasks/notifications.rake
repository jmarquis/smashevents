namespace :notifications do

  task new_events: [:environment] do

    Rails.logger.info 'Scanning for new event notifications that need to be sent...'
    notification_count = 0

    # We only do this notification once per tournament for Twitter, and just
    # list all the games regardless of player count as soon as one event has
    # crossed the display threshold.
    Tournament
      .should_display
      .where('tournaments.start_at > ?', Time.now)
      .order(start_at: :asc, name: :asc)
      .each do |tournament|
        begin
          Notification.send_notification(
            tournament,
            type: Notification::TYPE_TOURNAMENT_ADDED,
            platform: Notification::PLATFORM_TWITTER,
            idempotent: true
          ) do |tournament|
            Twitter.tournament_added(tournament)

            notification_count += 1

            # Avoid rate limits
            sleep 1
          end
        rescue X::Error
          # Swallow errors, they got logged from the Twitter class
        end
      end

    # For Discord we want to notify per event since there are separate channels
    # for each game.
    Tournament
      .should_display
      .where('tournaments.start_at > ?', Time.now)
      .order(start_at: :asc, name: :asc)
      .map(&:events)
      .flatten
      .each do |event|
        Notification.send_notification(
          event,
          type: Notification::TYPE_EVENT_ADDED,
          platform: Notification::PLATFORM_DISCORD,
          idempotent: true
        ) do |event|
          Discord.event_added(event)

          notification_count += 1

          # Avoid rate limits
          sleep 1
        end

        # Also set should_display here so this becomes perpetual.
        unless event.should_display
          event.should_display = true
          event.save
        end
      end

    Rails.logger.info "Done, sent #{notification_count} notifications."

  end

  task weekend_briefing: [:environment] do
    next unless Time.now.strftime('%a') == 'Wed' || Rails.env.development?

    Rails.logger.info 'Sending weekend briefing notifications...'
    notification_count = 0

    Tournament
      .should_display
      .where('end_at > ?', Time.now + 1.day)
      .where('tournaments.start_at < ?', Time.now + 5.days)
      .order(start_at: :asc, end_at: :asc, name: :asc)
      .map(&:events)
      .flatten
      .group_by(&:game)
      .each do |game, events|

        events = events.sort_by(&:player_count).reverse

        Notification.send_notification(
          events,
          type: Notification::TYPE_WEEKEND_BRIEFING,
          platform: Notification::PLATFORM_TWITTER,
          idempotent: true
        ) do |events|
          Twitter.weekend_briefing(game:, events:)

          notification_count += 1
        end

        Notification.send_notification(
          events,
          type: Notification::TYPE_WEEKEND_BRIEFING,
          platform: Notification::PLATFORM_DISCORD,
          idempotent: true
        ) do |events|
          Discord.weekend_briefing(game:, events:)

          notification_count += 1

          # Avoid rate limits
          sleep 1
        end
      end

    Rails.logger.info "Done, sent #{notification_count} notifications."
  end

  task congratulations: [:environment] do
    Rails.logger.info 'Sending congratulation notifications...'
    notification_count = 0

    effective_time = Time.now

    Tournament
      .should_display
      .where('end_at between ? and ?', effective_time - 1.day, effective_time)
      .order(start_at: :asc, end_at: :asc, name: :asc)
      .map(&:events)
      .flatten
      .filter { |event| event.winner_entrant.present? }
      .group_by(&:game)
      .each do |game, events|
        events = events.sort_by(&:player_count).reverse

        Notification.send_notification(
          events,
          type: Notification::TYPE_CONGRATULATIONS,
          platform: Notification::PLATFORM_TWITTER,
          idempotent: true
        ) do |events|
          Twitter.congratulations(game:, events:)

          notification_count += 1
        end
      end

    Rails.logger.info "Done, sent #{notification_count} notifications."
  end

  task happening_today: [:environment] do
    Rails.logger.info 'Sending happening today notifications...'
    notification_count = 0

    effective_time = Time.now

    Tournament
      .should_display
      .where('end_at > ?', effective_time)
      .where('tournaments.start_at < ?', effective_time + 2.days)
      .filter { |t| effective_time.in_time_zone(t.timezone || 'America/New_York') < t.end_at.in_time_zone(t.timezone || 'America/New_York') }
      .filter { |t| (effective_time + 12.hours).in_time_zone(t.timezone || 'America/New_York') > t.start_at.in_time_zone(t.timezone || 'America/New_York') }
      .each do |tournament|

        notification = Notification.where(
          notifiable: tournament,
          notification_type: Notification::TYPE_HAPPENING_TODAY,
          platform: Notification::PLATFORM_TWITTER,
          success: true
        ).order(sent_at: :desc).limit(1).first

        if notification.blank? || notification.sent_at.day != Time.now.day
          Rails.logger.info "Sending happening today tweet for #{tournament.slug}..."
          begin
            Notification.send_notification(
              tournament,
              type: Notification::TYPE_HAPPENING_TODAY,
              platform: Notification::PLATFORM_TWITTER
            ) do |tournament|
              Twitter.happening_today(tournament)

              notification_count += 1
            end
          rescue X::Error
          end
        end

        notification = Notification.where(
          notifiable: tournament,
          notification_type: Notification::TYPE_HAPPENING_TODAY,
          platform: Notification::PLATFORM_DISCORD,
          success: true
        ).order(sent_at: :desc).limit(1).first

        if notification.blank? || notification.sent_at.day != Time.now.day
          Rails.logger.info "Sending happening today Discord notification for #{tournament.slug}..."
          Notification.send_notification(
            tournament,
            type: Notification::TYPE_HAPPENING_TODAY,
            platform: Notification::PLATFORM_DISCORD
          ) do |tournament|
            Discord.happening_today(tournament)

            notification_count += 1
          end
        end

        # Avoid rate limits
        sleep 1

      end

    Rails.logger.info "Done, sent #{notification_count} notifications."
  end

end
