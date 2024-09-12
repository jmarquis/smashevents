class Twitter
  @client = nil

  class << self

    def notify_tournament_added(tournament)
      client.post('tweets', JSON.generate({
        text: <<~TEXT
          New tournament added to smashevents.gg!
          \n\n
          #{tournament.name.upcase}
          #{tournament.formatted_date_range}
          #{tournament.formatted_location}
          \n\n
          Featuring #{tournament.events.sort_by(&:player_count).reverse.map { |event| Game.by_slug(event.game).name }.to_sentence}!
          \n\n
          ##{tournament.hashtag}
          \n\n
          https://start.gg/#{tournament.slug}
        TEXT
      }))
    end

    def weekend_briefing(game:, events:)
      tournament_blurbs = events.map do |event|
        blurb = "#{event.tournament.name.upcase} (#{event.tournament.formatted_day_range})"

        if event.featured_players.present?
          blurb += " featuring #{[*event.featured_players, "#{(event.player_count - event.featured_players.count)} more!"].to_sentence}"
        else
          blurb += " featuring #{event.player_count} players!"
        end

        blurb += " ##{event.tournament.hashtag}" if event.tournament.hashtag.present?

        blurb
      end

      client.post('tweets', JSON.generate({
        text: <<~TEXT
          THIS WEEKEND IN #{game.name.upcase}
          \n\n
          #{tournament_blurbs.join("\n\n")}
        TEXT
      }))
    end
    
    def happening_today(tournament)
      streams = tournament.stream_data.blank? ? nil : tournament.stream_data.map do |stream|
        case stream['source'].downcase
        when Tournament::STREAM_SOURCE_TWITCH
          "https://twitch.tv/#{stream['name']}"
        when Tournament::STREAM_SOURCE_YOUTUBE
          "https://youtube.com/#{stream['name']}/live"
        end
      end.compact

      stream_text = streams.blank? ? nil : <<~TEXT
        \n\n
        Streams:
        #{streams.join("\n")}
      TEXT

      event_blurbs = tournament.events.sort_by(&:player_count).reverse.map do |event|
        game = Game.by_slug(event.game)
        if event.featured_players.present?
          "#{game.name.upcase}: featuring #{[*event.featured_players, "#{(event.player_count - event.featured_players.count)} more!"].to_sentence}"
        else
          "#{game.name.upcase}: featuring #{event.player_count} players!"
        end
      end

      client.post('tweets', JSON.generate({
        text: <<~TEXT
          HAPPENING TODAY (#{Time.now.strftime('%A')}): #{tournament.name.upcase}
          \n\n
          #{event_blurbs.join("\n\n")}
          #{stream_text}
          \n\n
          #{tournament.hashtag}
          https://start.gg/#{tournament.slug}
        TEXT
      }))
    end

    def client
      return @client if @client

      @client = X::Client.new(
        api_key: Rails.application.credentials.dig(:twitter, :api_key),
        api_key_secret: Rails.application.credentials.dig(:twitter, :api_key_secret),
        access_token: Rails.application.credentials.dig(:twitter, :access_token),
        access_token_secret: Rails.application.credentials.dig(:twitter, :access_token_secret)
      )
    end

  end
end
