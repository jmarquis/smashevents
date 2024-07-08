class ApplicationController < ActionController::Base

  def index

    if params[:melee] || params[:ultimate]
      @melee = params[:melee].present?
      @ultimate = params[:ultimate].present?
      cookies[:melee] = @melee
      cookies[:ultimate] = @ultimate
    else
      @melee = true unless ActiveModel::Type::Boolean.new.cast(cookies[:melee]) == false
      @ultimate = true unless ActiveModel::Type::Boolean.new.cast(cookies[:ultimate]) == false
    end

    @tournaments = Tournament.where('end_at > ?', Date.today - 1.day).order(start_at: :asc, name: :asc)

    if !@melee
      @tournaments = @tournaments.where('ultimate_player_count > ?', 0)
    elsif !@ultimate
      @tournamnets = @tournaments.where('melee_player_count > ?', 0)
    end

  end

  def index2

    if params[:game]
      @games = GameConfig.filter_valid_games(params[:game].split(','))
      cookies[:games] = @games.join(',')
    elsif cookies[:games].present?
      @games = GameConfig.filter_valid_games(cookies[:games].split(','))
    else
      @games = [GameConfig::MELEE[:slug], GameConfig::ULTIMATE[:slug]]
    end

    @games.map! { |game| GameConfig::GAMES[game] }

    @tournaments = Tournament.includes(:players).where('end_at > ?', Date.today - 1.day).order(start_at: :asc, name: :asc)


  end

end
