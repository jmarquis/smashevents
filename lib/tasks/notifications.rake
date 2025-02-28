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
      .filter { |tournament| tournament.should_display? }
      .filter { |tournament| tournament.events.map(&:notified_added_at).compact.empty? }
      .each do |tournament|
        puts "Sending tournament added Twitter notification about #{tournament.name}"

        begin
          Twitter.tournament_added(tournament)
        rescue X::Error
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
      .filter { |event| event.should_display? }
      .filter { |event| event.notified_added_at.blank? }
      .each do |event|
        puts "Sending tournament added Discord notification about #{event.tournament.name}"

        Discord.event_added(event)

        # Mark this notification as complete here since we do it per
        # event/game. Twitter notifications will ignore any tournament with
        # any event marked as notified.
        event.notified_added_at = Time.now
        event.save

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
      .filter { |event| event.should_display? }
      .group_by(&:game)
      .each do |game, events|

        puts "Sending weekend briefing tweet for #{game.slug.upcase} for #{events.map(&:tournament).map(&:slug).to_sentence}..."
        Twitter.weekend_briefing(
          game:,
          events: events.sort_by(&:player_count).reverse
        )

        puts "Sending weekend briefing Discord notification for #{game.slug.upcase} for #{events.map(&:tournament).map(&:slug).to_sentence}..."
        Discord.weekend_briefing(
          game:,
          events: events.sort_by(&:player_count).reverse
        )

        # Avoid rate limits
        sleep 1
      end
  end

  task congratulations: [:environment] do
    effective_time = Time.now - 11.days

    Tournament
      .includes(:events)
      .where('end_at > ?', effective_time - 3.days)
      .where('end_at < ?', effective_time)
      .where('start_at > ?', effective_time - 6.days)
      .order(start_at: :asc, end_at: :asc, name: :asc)
      .map(&:events)
      .flatten
      .filter { |event| event.should_display? }
      .tap do |events|
        next if events.blank?

        puts "Sending congratulations tweet for #{events.count} events"
        Twitter.congratulations(events)
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
      .filter { |t| t.should_display? }
      .each do |tournament|

        puts "Sending happening today tweet for #{tournament.slug}..."
        begin
          Twitter.happening_today(tournament)
        rescue X::Error
        end

        puts "Sending happening today Discord notification for #{tournament.slug}..."
        Discord.happening_today(tournament)

        # Avoid rate limits
        sleep 1
      end
  end

end
