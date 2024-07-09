module ApplicationHelper

  def date_range(t)
    if t.start_at.day == t.end_at.day
      t.start_at.strftime('%b %-d, %Y')
    elsif t.start_at.month == t.end_at.month
      "#{t.start_at.strftime('%b %-d')} – #{t.end_at.strftime('%-d, %Y')}"
    elsif t.start_at.year == t.end_at.year
      "#{t.start_at.strftime('%b %-d')} – #{t.end_at.strftime('%b %-d, %Y')}"
    else
      "#{t.start_at.strftime('%b %-d, %Y')} – #{t.end_at.strftime('%b %-d, %Y')}"
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
