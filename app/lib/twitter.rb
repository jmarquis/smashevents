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

      tweet(text)
    end

    def weekend_briefing(game:, events:)
      tournament_blurbs = events.map do |event|
        next unless event.should_display?

        blurb = "#{event.tournament.name.upcase} (#{event.tournament.formatted_day_range})"
        blurb += " featuring #{event.players_sentence(twitter: true)}"

        blurb += "\nhttps://start.gg/#{event.tournament.slug}"
        blurb += " ##{event.tournament.hashtag}" if event.tournament.hashtag.present?

        blurb
      end.compact

      return if tournament_blurbs.empty?

      text = <<~TEXT
        THIS WEEKEND IN #{game.name.upcase}
        \n\n
        #{tournament_blurbs.join("\n\n")}
      TEXT

      banner_images = events.slice(0, 3).map(&:tournament).map(&:banner_image_file)

      tweet(text, images: banner_images)
    end

    def happening_today(tournament)
      return unless tournament.events.map(&:should_display?).any?

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

      # Don't filter by should_display?, might as well just show all the events
      # on the day of.
      event_blurbs = tournament.events.sort_by(&:player_count).reverse.map do |event|
        game = Game.by_slug(event.game)
        "#{game.name.upcase} featuring #{event.players_sentence(twitter: true)}"
      end

      text = <<~TEXT
        HAPPENING TODAY (#{Time.now.strftime('%A')}): #{tournament.name.upcase}
        https://start.gg/#{tournament.slug}#{tournament.hashtag.present? ? " ##{tournament.hashtag}" : nil}
        \n\n
        #{event_blurbs.join("\n\n")}
        #{stream_text}
      TEXT

      tweet(text, images: [tournament.banner_image_file])
    end

    def tweet(text, images: [])
      text = text.slice(0, 260) if Rails.env.development?

      media_ids = images.map do |image|
        image.present? ? upload_image(image)['media_id_string'] : nil
      end.compact

      StatsD.measure('twitter.tweet') do
        client.post('tweets', JSON.generate({
          text:,
          media: media_ids.blank? ? nil : { media_ids: }
        }.compact))
      rescue X::Error => e
        puts "ERROR POSTING TO TWITTER: #{e.message}"
        raise e
      end
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
      StatsD.measure('twitter.upload_image') do
        X::MediaUploader.upload(client:, file_path:, media_category: 'tweet_image')
      end
    end

  end
end
