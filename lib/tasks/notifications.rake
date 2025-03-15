namespace :notifications do

  task new_events: [:environment] do

    puts 'Scanning for new event notifications that need to be sent...'

    # We only do this notification once per tournament for Twitter, and just
    # list all the games regardless of player count as soon as one event has
    # crossed the display threshold.
    Tournament
      .includes(:events)
      .where('start_at > ?', Time.now)
      .order(start_at: :asc, name: :asc)
      .filter(&:should_display?)
      .each do |tournament|
        begin
          Notification.log(
            tournament,
            type: Notification::TYPE_TOURNAMENT_ADDED,
            platform: Notification::PLATFORM_TWITTER,
            idempotent: true
          ) do |tournament|
            Twitter.tournament_added(tournament)
          end
        rescue X::Error
          # Swallow errors, they got logged from the Twitter class
        end

        # Avoid rate limits
        sleep 1
      end

    # For Discord we want to notify per event since there are separate channels
    # for each game.
    Tournament
      .includes(:events)
      .where('start_at > ?', Time.now)
      .order(start_at: :asc, name: :asc)
      .map(&:events)
      .flatten
      .filter(&:should_display?)
      .each do |event|
        Notification.log(
          event,
          type: Notification::TYPE_EVENT_ADDED,
          platform: Notification::PLATFORM_DISCORD,
          idempotent: true
        ) do |event|
          Discord.event_added(event)
        end

        # Avoid rate limits
        sleep 1
      end

  end

  task weekend_briefing: [:environment] do
    next unless Time.now.strftime('%a') == 'Wed' || Rails.env.development?

    Tournament
      .includes(:events)
      .where('end_at > ?', Time.now + 1.day)
      .where('start_at < ?', Time.now + 5.days)
      .order(start_at: :asc, end_at: :asc, name: :asc)
      .map(&:events)
      .flatten
      .filter(&:should_display?)
      .group_by(&:game)
      .each do |game, events|

        Notification.log(
          events,
          type: Notification::TYPE_WEEKEND_BRIEFING,
          platform: Notification::PLATFORM_TWITTER,
          idempotent: true
        ) do |events|
          Twitter.weekend_briefing(
            game:,
            events: events.sort_by(&:player_count).reverse
          )
        end

        Notification.log(
          events,
          type: Notification::TYPE_WEEKEND_BRIEFING,
          platform: Notification::PLATFORM_DISCORD,
          idempotent: true
        ) do |events|
          Discord.weekend_briefing(
            game:,
            events: events.sort_by(&:player_count).reverse
          )
        end

        # Avoid rate limits
        sleep 1
      end
  end

  task congratulations: [:environment] do
    effective_time = Time.now

    Tournament
      .includes(:events)
      .where('end_at between ? and ?', effective_time - 1.day, effective_time)
      .order(start_at: :asc, end_at: :asc, name: :asc)
      .map(&:events)
      .flatten
      .filter(&:should_display?)
      .filter { |event| event.winner_entrant.present? }
      .sort_by(&:player_count)
      .reverse
      .tap do |events|
        next if events.blank?

        Notification.log(
          events,
          type: Notification::TYPE_CONGRATULATIONS,
          platform: Notification::PLATFORM_TWITTER,
          idempotent: true
        ) do |events|
          Twitter.congratulations(events)
        end
      end
  end

  task happening_today: [:environment] do
    effective_time = Time.now

    Tournament
      .includes(:events)
      .where('end_at > ?', effective_time)
      .where('start_at < ?', effective_time + 2.days)
      .filter { |t| effective_time.in_time_zone(t.timezone || 'America/New_York') < t.end_at.in_time_zone(t.timezone || 'America/New_York') }
      .filter { |t| (effective_time + 12.hours).in_time_zone(t.timezone || 'America/New_York') > t.start_at.in_time_zone(t.timezone || 'America/New_York') }
      .filter(&:should_display?)
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

        puts "Sending happening today tweet for #{tournament.slug}..."
        begin
          Notification.log(
            tournament,
            type: Notification::TYPE_HAPPENING_TODAY,
            platform: Notification::PLATFORM_TWITTER
          ) do |tournament|
            Twitter.happening_today(tournament)
          end
        rescue X::Error
        end

        puts "Sending happening today Discord notification for #{tournament.slug}..."
        Notification.log(
          tournament,
          type: Notification::TYPE_HAPPENING_TODAY,
          platform: Notification::PLATFORM_DISCORD
        ) do |tournament|
          Discord.happening_today(tournament)
        end

        # Avoid rate limits
        sleep 1
      end
  end

end
