class ApplicationController < ActionController::Base

  def index

    # TODO: support old params / cookies for melee + ultimate

    game_list = [GameConfig::MELEE[:slug], GameConfig::ULTIMATE[:slug]]
    if params[:games].present?
      game_list = GameConfig.filter_valid_games(params[:game].split(','))
      cookies[:games] = game_list.join(',')
    elsif cookies[:games].present?
      game_list = GameConfig.filter_valid_games(cookies[:games].split(','))
      cookies[:games] = game_list.join(',')
    end

    @games = game_list.map { |game| GameConfig::GAMES[game] }

    @tournaments = Tournament
      .includes(:events)
      .where('end_at > ?', Date.today - 1.day)
      .where(events: { game: game_list })
      .order(start_at: :asc, name: :asc)

  end

end
