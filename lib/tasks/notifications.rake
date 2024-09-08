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
    Tournament
      .includes(:events)
      .where('end_at > ?', Time.now)
      .where('start_at < ?', Time.now + 2.days)
      .filter { |t| t.start_at.in_time_zone(t.timezone || 'America/New_York').day == Time.now.in_time_zone(t.timezone || 'America/New_York').day }
      .each do |tournament|
        puts "Sending happening today tweet for #{tournament.slug}..."
        Twitter.happening_today(tournament)
      end
  end

end
