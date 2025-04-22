namespace :notifications do

  task new_events: [:environment] do

    Rails.logger.info 'Scanning for new event notifications that need to be sent...'

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

          # Avoid rate limits
          sleep 1
        end

        # Also set should_display here so this becomes perpetual.
        unless event.should_display
          event.should_display = true
          event.save
        end
      end

  end

  task weekend_briefing: [:environment] do
    next unless Time.now.strftime('%a') == 'Wed' || Rails.env.development?

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
        end

        Notification.send_notification(
          events,
          type: Notification::TYPE_WEEKEND_BRIEFING,
          platform: Notification::PLATFORM_DISCORD,
          idempotent: true
        ) do |events|
          Discord.weekend_briefing(game:, events:)

          # Avoid rate limits
          sleep 1
        end
      end
  end

  task congratulations: [:environment] do
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
        end
      end
  end

  task happening_today: [:environment] do
    effective_time = Time.now

    Tournament
      .should_display
      .where('end_at > ?', effective_time)
      .where('tournaments.start_at < ?', effective_time + 2.days)
      .filter { |t| effective_time.in_time_zone(t.timezone || 'America/New_York') < t.end_at.in_time_zone(t.timezone || 'America/New_York') }
      .filter { |t| (effective_time + 12.hours).in_time_zone(t.timezone || 'America/New_York') > t.start_at.in_time_zone(t.timezone || 'America/New_York') }
      .filter { |t|

        # Custom idempotency logic since a multi-day tournament is supposed to
        # have more than one of these.
        notification = Notification.where(
          notifiable: t,
          notification_type: Notification::TYPE_HAPPENING_TODAY,
          platform: Notification::PLATFORM_TWITTER,
          success: true
        ).order(sent_at: :desc).limit(1).first

        notification.blank? || notification.sent_at.day != Time.now.day

      }
      .each do |tournament|

        Rails.logger.info "Sending happening today tweet for #{tournament.slug}..."
        begin
          Notification.send_notification(
            tournament,
            type: Notification::TYPE_HAPPENING_TODAY,
            platform: Notification::PLATFORM_TWITTER
          ) do |tournament|
            Twitter.happening_today(tournament)
          end
        rescue X::Error
        end

        Rails.logger.info "Sending happening today Discord notification for #{tournament.slug}..."
        Notification.send_notification(
          tournament,
          type: Notification::TYPE_HAPPENING_TODAY,
          platform: Notification::PLATFORM_DISCORD
        ) do |tournament|
          Discord.happening_today(tournament)

          # Avoid rate limits
          sleep 1
        end
      end
  end

end
