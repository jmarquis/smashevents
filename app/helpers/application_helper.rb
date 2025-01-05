module ApplicationHelper

  def add_game_link(game, selected_games)
    link_to "+ #{game.name}", CGI::unescape(url_for(games: (selected_games.map(&:slug) + [game.slug]).join(',')))
  end

  def remove_game_link(game, selected_games)
    new_selected_games = selected_games.reject { |selected_game| selected_game.slug == game.slug }
    link_to 'X', CGI::unescape(new_selected_games.count == 1 ? url_for(game: new_selected_games.first.slug) : url_for(games: new_selected_games.map(&:slug).join(',')))
  end

  def stream_link(stream)
    stream = stream.with_indifferent_access

    case stream[:source].downcase
    when Tournament::STREAM_SOURCE_TWITCH
      link_to stream[:name], "https://twitch.tv/#{stream[:name]}",
        target: '_blank',
        title: stream[:status] == Tournament::STREAM_STATUS_LIVE ? "#{stream[:game]} | #{stream[:title]}" : nil
    when Tournament::STREAM_SOURCE_YOUTUBE
      link_to stream[:name], stream[:url], target: '_blank'
    end
  end

  def colors_css(action)
    case action
    when 'past' 
      [
        '--color-bg: #121212',
        '--color-bg-2: #353535',
        '--color-text: #9d9d9d',
        '--color-text-2: #555555',
        '--color-text-3: #f1f1f1',
      ].join(';')
    else
      [
        '--color-bg: #081212',
        '--color-bg-2: #183535',
        '--color-text: #859d9d',
        '--color-text-2: #445555',
        '--color-text-3: #ebf1f1',
      ].join(';')
    end
  end

  def react_component(component, props)
    render 'react_component', locals: {
      component:,
      props: props
        .merge({ csrf_token: form_authenticity_token })
        .deep_transform_keys do |key|
          key.to_s.camelize(:lower)
        end
        .to_json
    }
  end

end
