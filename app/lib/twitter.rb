class Twitter
  @client = nil

  class << self

    def tournament_added(tournament)
      text = <<~TEXT
        New tournament added to smashevents.gg!
        \n\n
        #{tournament.name.upcase}
        #{tournament.formatted_date_range}
        #{tournament.formatted_location}
        \n\n
        Featuring #{tournament.events.sort_by(&:player_count).reverse.map { |event| Game.by_slug(event.game).name }.to_sentence}!
        #{tournament.hashtag.present? ? "\n\n##{tournament.hashtag}" : nil}
        \n\n
        https://start.gg/#{tournament.slug}
      TEXT

      text = text.slice(0, 260) if Rails.env.development?

      client.post('tweets', JSON.generate({ text: }))
    end

    def weekend_briefing(game:, events:)
      tournament_blurbs = events.map do |event|
        blurb = "#{event.tournament.name.upcase} (#{event.tournament.formatted_day_range})"

        if event.featured_players.present?
          blurb += " featuring #{[*event.featured_players, "#{(event.player_count - event.featured_players.count)} more!"].to_sentence}"
        else
          blurb += " featuring #{event.player_count} players!"
        end

        blurb += "\nhttps://start.gg/#{event.tournament.slug}"
        blurb += " ##{event.tournament.hashtag}" if event.tournament.hashtag.present?

        blurb
      end

      text = <<~TEXT
        THIS WEEKEND IN #{game.name.upcase}
        \n\n
        #{tournament_blurbs.join("\n\n")}
      TEXT

      text = text.slice(0, 260) if Rails.env.development?

      media_ids = events.slice(0, 3).map do |event|
        event.tournament.banner_image_file.present? ? upload_image(event.tournament.banner_image_file)['media_id_string'] : nil
      end.compact

      client.post('tweets', JSON.generate({
        text:,
        media: media_ids.blank? ? nil : { media_ids: }
      }.compact))
    end
    
    def happening_today(tournament)
      streams = tournament.stream_data.blank? ? nil : tournament.stream_data.map do |stream|
        case stream['source'].downcase
        when Tournament::STREAM_SOURCE_TWITCH
          "https://twitch.tv/#{stream['name']}"
        when Tournament::STREAM_SOURCE_YOUTUBE
          "#{Youtube.channel_url(stream['name'])}/live"
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
          "#{game.name.upcase} featuring #{[*event.featured_players, "#{(event.player_count - event.featured_players.count)} more!"].to_sentence}"
        else
          "#{game.name.upcase} featuring #{event.player_count} players!"
        end
      end

      text = <<~TEXT
        HAPPENING TODAY (#{Time.now.strftime('%A')}): #{tournament.name.upcase}
        https://start.gg/#{tournament.slug}#{tournament.hashtag.present? ? " ##{tournament.hashtag}" : nil}
        \n\n
        #{event_blurbs.join("\n\n")}
        #{stream_text}
      TEXT

      text = text.slice(0, 260) if Rails.env.development?

      media_ids = tournament.banner_image_file.blank? ? nil : [upload_image(tournament.banner_image_file)['media_id_string']]

      client.post('tweets', JSON.generate({
        text:,
        media: media_ids.blank? ? nil : { media_ids: }
      }.compact))
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

    def upload_image(file_path)
      X::MediaUploader.upload(client:, file_path:, media_category: 'tweet_image')
    end

  end
end
