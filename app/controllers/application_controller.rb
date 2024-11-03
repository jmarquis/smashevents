class ApplicationController < ActionController::Base

  def index

    game_slugs = nil
    if params[:game].present?
      game_slugs = Game.filter_valid_game_slugs([params[:game]])
    elsif params[:games].present?
      game_slugs = Game.filter_valid_game_slugs(params[:games].split(','))
    elsif cookies[:games].present?
      game_slugs = Game.filter_valid_game_slugs(cookies[:games].split(','))
    end

    game_slugs = ['melee', 'ultimate'] if game_slugs.blank?
    cookies.permanent[:games] = game_slugs.join(',')
    @games = game_slugs.map { |slug| Game.find_by(slug:) }
    @unselected_games = Game.all_games_except(@games)

    @tournaments = Tournament
      .includes(:override, events: [:game, entrants: :player])
      # Leave a few hours of leeway for events that run long
      .where('end_at > ?', Time.now - 6.hours)
      .where(events: { game: @games })
      .merge(
        Tournament.where(override: { include: true }).or(
          Tournament.where.not(events: { player_count: nil }).merge(
            Tournament.where('coalesce(events.ranked_player_count, 0) / case when coalesce(events.player_count, 1) = 0 then 1 else coalesce(events.player_count, 1) end > ?', 0.3).or(
              Tournament.where('events.ranked_player_count > ?', 10)
            ).or(
              Tournament.where('coalesce(events.player_count, 0) + (coalesce(events.ranked_player_count, 0) * 10) > games.display_threshold')
            )
          )
        )
      )

    if params[:player]
      @tournaments = @tournaments.where('LOWER(players.tag) = ?', params[:player].downcase)
    end

    @tournaments = @tournaments.order(start_at: :asc, end_at: :asc, name: :asc)

  end

end
