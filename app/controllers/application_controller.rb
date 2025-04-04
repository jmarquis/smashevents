class ApplicationController < BaseController

  def index
    @games = selected_games
    @unselected_games = Game.all_games_except(@games)

    @tournaments = Tournament.should_display(games: @games)
      # Leave a few hours of leeway for events that run long
      .where('end_at > ?', Time.now - 6.hours)
      .order(start_at: :asc, end_at: :asc, name: :asc)

    if params[:player]
      @tournaments = @tournaments
        .joins(events: { entrants: :player})
        .where('LOWER(players.tag) = ?', params[:player].downcase)
    end

    @tournaments = @tournaments.filter do |tournament|
      tournament.events.any? { |event| !event.completed? }
    end
  end

  def past
    @games = selected_games
    @unselected_games = Game.all_games_except(@games)

    @tournaments = Tournament.should_display(games: @games)
      .where('end_at < ?', Time.now + 7.days)
      .where('end_at > ?', Time.now - 6.months)
      .order(end_at: :desc, start_at: :desc, name: :asc)
      .limit(50)

    if params[:player]
      @tournaments = @tournaments
        .joins(events: { entrants: :player })
        .where('LOWER(players.tag) = ?', params[:player].downcase)
    end

    @tournaments = @tournaments.filter do |tournament|
      tournament.events.any?(&:completed?)
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

end
