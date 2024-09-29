class ApplicationController < ActionController::Base

  def index

    game_list = nil
    if params[:game].present?
      game_list = Game.filter_valid_game_slugs([params[:game]])
    elsif params[:games].present?
      game_list = Game.filter_valid_game_slugs(params[:games].split(','))
    elsif cookies[:games].present?
      game_list = Game.filter_valid_game_slugs(cookies[:games].split(','))
    end

    game_list = [Game::MELEE.slug, Game::ULTIMATE.slug] if game_list.blank?
    cookies.permanent[:games] = game_list.join(',')
    @games = game_list.map { |slug| Game.by_slug(slug) }
    @unselected_games = Game.all_games_except(@games)

    @tournaments = Tournament
      .includes(:events)
      # Leave a few hours of leeway for events that run long
      .where('end_at > ?', Time.now - 6.hours)
      .where(events: { game: game_list })
      .order(start_at: :asc, end_at: :asc, name: :asc)

    # Only show tournaments that are interesting based on the selected games
    @tournaments = @tournaments.filter { |t| t.should_display?(games: game_list) }

  end

end
