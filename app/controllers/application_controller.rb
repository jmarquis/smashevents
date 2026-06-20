class ApplicationController < BaseController
  layout 'events'

  def index
    @title = 'Smash Radar: Upcoming Smash & Rivals tournaments!'
    @description = 'Find out about the biggest upcoming Super Smash Bros. Melee, Ultimate, 64, and Rivals of Aether tournaments!'

    @games = selected_games
    @unselected_games = Game.all_games_except(@games)

    @games.each do |game|
      StatsD.increment("view.index.#{game.slug}")
    end

    @tournaments = Tournament.should_display(games: @games)
      # Leave a few hours of leeway for events that run long
      .where('end_at > ?', 6.hours.ago)
      .where.not(events: { state: Event::STATE_COMPLETED })
      .order(start_at: :asc, end_at: :asc, name: :asc)

    if params[:player]
      @tournaments = @tournaments
        .joins(events: { entrants: :player })
        .where('LOWER(players.tag) = ?', params[:player].downcase)
    end

    if params[:last_tournament_id].present?
      last_tournament = Tournament.find(params[:last_tournament_id])
      @tournaments = @tournaments.where('(tournaments.start_at, tournaments.end_at, tournaments.name) > (?, ?, ?)', last_tournament.start_at, last_tournament.end_at, last_tournament.name)

      StatsD.increment('view.index_scroll')

      render :index, layout: nil
    end
  end

  def past
    @title = 'Smash Radar: Upcoming Smash & Rivals tournaments!'
    @description = 'Find out about the biggest upcoming Super Smash Bros. Melee, Ultimate, 64, and Rivals of Aether tournaments!'

    @games = selected_games
    @unselected_games = Game.all_games_except(@games)

    @games.each do |game|
      StatsD.increment("view.past.#{game.slug}")
    end

    @tournaments = Tournament.should_display(games: @games)
      .where('end_at < ?', Time.now + 7.days)
      .where.not(
        id: Tournament.joins(:events).where.not(events: { state: Event::STATE_COMPLETED })
      )
      .order(end_at: :desc, start_at: :desc, name: :desc)

    if params[:player]
      @tournaments = @tournaments
        .joins(events: { entrants: :player })
        .where('LOWER(players.tag) = ?', params[:player].downcase)
    end

    if params[:last_tournament_id].present?
      last_tournament = Tournament.find(params[:last_tournament_id])
      @tournaments = @tournaments.where('(tournaments.start_at, tournaments.end_at, tournaments.name) < (?, ?, ?)', last_tournament.start_at, last_tournament.end_at, last_tournament.name)

      StatsD.increment('view.past_scroll')

      return render :index, layout: nil
    end

    render :index
  end

  def setbot
    @title = 'Setbot: a Discord bot for Smash & Rivals streams'
    @description = 'A Discord bot that notifies when a Smash/Rivals player is on a tournament stream.'
    @h1 = 'Setbot'

    render layout: 'minimal'
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

    game_slugs = ['melee', 'ultimate', 'smash64', 'remix', 'rivals', 'rivals2'] if game_slugs.blank?
    cookies.permanent[:games] = game_slugs.join(',')
    game_slugs.map { |slug| Game.find_by(slug:) }
  end
end
