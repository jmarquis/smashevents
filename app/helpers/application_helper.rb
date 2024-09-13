module ApplicationHelper

  def add_game_link(game, selected_games)
    link_to "+ #{game.name}", CGI::unescape(root_path(games: (selected_games.map(&:slug) + [game.slug]).join(',')))
  end

  def remove_game_link(game, selected_games)
    new_selected_games = selected_games.reject { |selected_game| selected_game.slug == game.slug }
    link_to 'X', CGI::unescape(new_selected_games.count == 1 ? root_path(game: new_selected_games.first.slug) : root_path(games: new_selected_games.map(&:slug).join(',')))
  end

  def stream_link(stream)
    stream = stream.with_indifferent_access

    case stream[:source].downcase
    when Tournament::STREAM_SOURCE_TWITCH
      link_to stream[:name], "https://twitch.tv/#{stream[:name]}",
        target: '_blank',
        title: stream[:status] == Tournament::STREAM_STATUS_LIVE ? "#{stream[:game]} | #{stream[:title]}" : nil
    when Tournament::STREAM_SOURCE_YOUTUBE
      link_to stream[:name], "#{Youtube.channel_url(stream[:name])}/live", target: '_blank'
    end
  end

end
