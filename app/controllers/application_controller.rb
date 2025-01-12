class ApplicationController < ActionController::Base

  def index
    @games = selected_games
    @unselected_games = Game.all_games_except(@games)

    @tournaments = tournaments(@games)
      # Leave a few hours of leeway for events that run long
      .where('end_at > ?', Time.now - 6.hours)
      .order(start_at: :asc, end_at: :asc, name: :asc)

    if params[:player]
      @tournaments = @tournaments.joins(events: { entrants: :player}).where('LOWER(players.tag) = ?', params[:player].downcase)
    end
  end

  def past
    @games = selected_games
    @unselected_games = Game.all_games_except(@games)

    @tournaments = tournaments(@games)
      .where('end_at < ?', Time.now)
      .where('end_at > ?', Time.now - 6.months)
      .order(start_at: :desc, end_at: :desc, name: :asc)
      .limit(50)

    if params[:player]
      @tournaments = @tournaments.joins(events: { entrants: :player }).where('LOWER(players.tag) = ?', params[:player].downcase)
    end

    render :index
  end

  private

  def selected_games
    game_slugs = nil
    if params[:game].present?
      game_slugs = Game.filter_valid_game_slugs([params[:game]])
    elsif params[:games].present?
      game_slugs = Game.filter_valid_game_slugs(params[:games].split(','))
    elsif cookies[:games].present?
      game_slugs = Game.filter_valid_game_slugs(cookies[:games].split(','))
    end

    game_slugs = ['melee', 'ultimate', 'smash64', 'rivals', 'rivals2'] if game_slugs.blank?
    cookies.permanent[:games] = game_slugs.join(',')
    game_slugs.map { |slug| Game.find_by(slug:) }
  end

  def tournaments(games)
    Tournament
      .includes(:override, events: [:game, winner_entrant: :player])
      .where(events: { game: games })
      .merge(
        Tournament.where(override: { include: true }).or(
          Tournament.where("end_at - tournaments.start_at <= interval '7 days'").merge(
            Tournament.where.not(events: { player_count: nil }).merge(
              Tournament.where('coalesce(events.player_count, 0) >= 8').merge(
                Tournament.where('coalesce(events.ranked_player_count, 0)::float / case when coalesce(events.player_count, 1) = 0 then 1.0 else coalesce(events.player_count, 1)::float end > ?', 0.3).or(
                  Tournament.where('events.ranked_player_count > ?', 10)
                ).or(
                  Tournament.where('coalesce(events.player_count, 0) + (coalesce(events.ranked_player_count, 0) * 10) > games.display_threshold')
                )
              )
            )
          )
        )
      )
  end

end
