module ApplicationHelper

  def date_range(tournament)
    start_at = tournament.start_at.in_time_zone(tournament.timezone || 'America/New_York')
    end_at = tournament.end_at.in_time_zone(tournament.timezone || 'America/New_York')
    if start_at.day == end_at.day
      start_at.strftime('%b %-d, %Y')
    elsif start_at.month == end_at.month
      "#{start_at.strftime('%b %-d')} – #{end_at.strftime('%-d, %Y')}"
    elsif start_at.year == end_at.year
      "#{start_at.strftime('%b %-d')} – #{end_at.strftime('%b %-d, %Y')}"
    else
      "#{start_at.strftime('%b %-d, %Y')} – #{end_at.strftime('%b %-d, %Y')}"
    end
  end

  def add_game_link(game, selected_games)
    link_to "+ #{game.name}", CGI::unescape(root_path(games: (selected_games.map(&:slug) + [game.slug]).join(',')))
  end

  def remove_game_link(game, selected_games)
    new_selected_games = selected_games.reject { |selected_game| selected_game.slug == game.slug }
    link_to 'X', CGI::unescape(new_selected_games.count == 1 ? root_path(game: new_selected_games.first.slug) : root_path(games: new_selected_games.map(&:slug).join(',')))
  end

end
