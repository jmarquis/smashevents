class Discord
  @clients = {}

  class << self

    def notify_tournament_added(tournament)
      tournament.events.group_by(&:game).each do |game_slug, events|
        client(game_slug).execute do |builder|
          builder.content = 'New tournament added!'
          builder.add_embed do |embed|
            embed.title = tournament.name
            embed.url = "https://start.gg/#{tournament.slug}"
            embed.description = <<~TEXT
              #{tournament.formatted_date_range}
              #{tournament.formatted_location}
              
              #{tournament.events.map { |event|
                "#{Game.by_slug(event.game).name}: #{event.player_count || 0} players"
              }.join("\n")}
            TEXT
            embed.timestamp = tournament.start_at
          end
        end
      end
    end

    def weekend_briefing(game:, events:)
      client(game.slug).execute do |builder|
        builder.content = "**This weekend in #{game.name}**"
        events.each do |event|
          builder.add_embed do |embed|
            embed.title = "#{event.tournament.name} (#{event.tournament.formatted_day_range})"
            embed.url = "https://start.gg/#{event.tournament.slug}"
            embed.description = <<~TEXT
              #{event.tournament.formatted_date_range}
              #{event.tournament.formatted_location}
            TEXT

            if event.featured_players.present?
              embed.description += <<~TEXT

                Featuring #{[*event.featured_players, "#{(event.player_count - event.featured_players.count)} more!"].to_sentence}
              TEXT
            end
          end
        end
      end
    end

    def happening_today(tournament)
      streams = tournament.stream_data.blank? ? nil : tournament.stream_data.map do |stream|
        case stream['source'].downcase
        when Tournament::STREAM_SOURCE_TWITCH
          "[#{stream['name']}](https://twitch.tv/#{stream['name']})"
        when Tournament::STREAM_SOURCE_YOUTUBE
          "[#{stream['name']}](https://youtube.com/#{stream['name']}/live)"
        end
      end.compact

      stream_text = streams.blank? ? nil : <<~TEXT
        
        Streams:
        #{streams.join("\n")}
      TEXT

      binding.pry

      tournament.events.group_by(&:game).each do |game_slug, events|
        client(game_slug).execute do |builder|
          builder.content = '**Happening today!**'
          builder.add_embed do |embed|
            embed.title = tournament.name
            embed.url = "https://start.gg/#{tournament.slug}"
            embed.description = <<~TEXT
              #{tournament.formatted_location}
              #{stream_text}
            TEXT
          end
        end
      end
    end

    def client(game_slug)
      return @clients[game_slug.to_sym] if @clients[game_slug.to_sym].present?

      @clients[game_slug.to_sym] = Discordrb::Webhooks::Client.new(url: Rails.application.credentials.dig(:discord, :webhook_urls, game_slug.to_sym))
    end

  end
end
