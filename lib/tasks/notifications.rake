namespace :notifications do

  task weekend_briefing: [:environment] do
    return unless Time.now.strftime('%a') == 'Wed'

    Tournament
      .includes(:events)
      .where('end_at > ?', Time.now)
      .where('start_at < ?', Time.now + 5.days)
      .order(start_at: :asc, end_at: :asc, name: :asc)
      .map(&:events)
      .flatten
      .group_by(&:game)
      .each do |game_slug, events|
        puts "Sending weekend briefing tweet for #{game_slug.upcase} for #{events.map(&:tournament).map(&:slug).to_sentence}..."

        Twitter.weekend_briefing(
          game: Game.by_slug(game_slug),
          events: events.sort_by(&:player_count).reverse
        )
      end
  end

  task happening_today: [:environment] do
    effective_time = Time.now

    Tournament
      .includes(:events)
      .where('end_at > ?', effective_time)
      .where('start_at < ?', effective_time + 2.days)
      .filter { |t| effective_time.in_time_zone(t.timezone || 'America/New_York') < t.end_at.in_time_zone(t.timezone || 'America/New_York') && (effective_time + 12.hours).in_time_zone(t.timezone || 'America/New_York') > t.start_at.in_time_zone(t.timezone || 'America/New_York') }
      .each do |tournament|
        puts "Sending happening today tweet for #{tournament.slug}..."
        Twitter.happening_today(tournament)
      end
  end

end
