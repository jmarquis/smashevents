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

    # For Discord we want to notify per event and group by game since there are
    # separate channels for each game.
    Tournament
      .includes(:events)
      .where('start_at > ?', Time.now)
      .order(start_at: :asc, name: :asc)
      .map(&:events)
      .flatten
      .filter { |event| event.should_display? }
      .filter { |event| event.notified_added_at.blank? }
      .group_by(&:game)
      .each do |game_slug, events|
        events.each do |event|
          puts "Sending event added Discord notification about #{event.tournament.name} / #{event.game}"
          Discord.event_added(game_slug, event)

          # Mark this notification as complete here since we do it per
          # event/game. Twitter notifications will ignore any tournament with
          # any event marked as notified.
          event.notified_added_at = Time.now
          event.save

          # Avoid rate limits
          sleep 1
        end
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
      .each do |game_slug, events|
        puts "Sending weekend briefing notifications for #{game_slug.upcase} for #{events.map(&:tournament).map(&:slug).to_sentence}..."

        Twitter.weekend_briefing(
          game: Game.by_slug(game_slug),
          events: events.sort_by(&:player_count).reverse
        )

        Discord.weekend_briefing(
          game: Game.by_slug(game_slug),
          events: events.sort_by(&:player_count).reverse
        )

        # Avoid rate limits
        sleep 1
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
        puts "Sending happening today notifications for #{tournament.slug}..."
        Twitter.happening_today(tournament)
        Discord.happening_today(tournament)

        # Avoid rate limits
        sleep 1
      end
  end

end
