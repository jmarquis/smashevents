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
        Twitter.weekend_briefing(
          game: Game.by_slug(game_slug),
          events: events.sort_by(&:player_count).reverse
        )
      end
  end

end
