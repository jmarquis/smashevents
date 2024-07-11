class ApplicationController < ActionController::Base

  def index

    game_list = nil
    if params[:game].present?
      game_list = Game.filter_valid_game_slugs([params[:game]])
    elsif params[:games].present?
      game_list = Game.filter_valid_game_slugs(params[:games].split(','))
    elsif params[:melee].present? || params[:ultimate].present?
      # TODO: Remove this eventually
      games = [params[:melee] && Game::MELEE.slug, params[:ultimate] && Game::ULTIMATE.slug].filter(&:present?)
      return redirect_to CGI::unescape(games.count > 1 ? root_path(games: games.join(',')) : root_path(game: games.first))
    elsif cookies[:games].present?
      game_list = Game.filter_valid_game_slugs(cookies[:games].split(','))
    elsif cookies[:melee].present? || cookies[:ultimate].present?
      # TODO: Remove this eventually
      games = [cookies[:melee] && Game::MELEE.slug, cookies[:ultimate] && Game::ULTIMATE.slug].filter(&:present?)
      return redirect_to CGI::unescape(games.count > 1 ? root_path(games: games.join(',')) : root_path(game: games.first))
    end

    game_list = [Game::MELEE.slug, Game::ULTIMATE.slug] if game_list.blank?
    cookies[:games] = game_list.join(',')
    @games = game_list.map { |slug| Game.by_slug(slug) }
    @unselected_games = Game.all_games_except(@games)

    @tournaments = Tournament
      .includes(:events)
      # Leave a few hours of leeway for events that run long
      .where('end_at > ?', Time.now - 6.hours)
      .where(events: { game: game_list })
      .order(start_at: :asc, end_at: :asc, name: :asc)

    # Only show tournaments that are interesting based on the selected games
    @tournaments = @tournaments.to_a.filter { |t| t.interesting?(games: game_list) }

  end

end
