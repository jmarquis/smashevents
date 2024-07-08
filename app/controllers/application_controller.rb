class ApplicationController < ActionController::Base

  def index

    # TODO: support old params / cookies for melee + ultimate

    game_list = [Game::MELEE.slug, Game::ULTIMATE.slug]
    if params[:games].present?
      game_list = Game.filter_valid_game_slugs(params[:game].split(','))
      cookies[:games] = game_list.join(',')
    elsif cookies[:games].present?
      game_list = Game.filter_valid_game_slugs(cookies[:games].split(','))
      cookies[:games] = game_list.join(',')
    end

    @games = game_list.map { |slug| Game.by_slug(slug) }

    @tournaments = Tournament
      .includes(:events)
      .where('end_at > ?', Date.today - 1.day)
      .where(events: { game: game_list })
      .order(start_at: :asc, name: :asc)

  end

end
