class Discord < Api
  @clients = {}
  @bot = nil

  DEFAULT_FOOTER = Discordrb::Webhooks::EmbedFooter.new(
    text: 'smashevents.gg',
    icon_url: 'https://smashevents.gg/favicon.png'
  )

  class << self

    def event_added(event)
      post(game_channel_id(event.game_slug)) do |builder|
        builder.content = '## NEW EVENT ADDED'
        builder.add_embed do |embed|
          embed.title = event.tournament.name
          embed.url = "https://start.gg/#{event.tournament.slug}"

          players_blurb = if event.player_count.present? && event.player_count > 0
            blurb = "#{event.player_count} players"

            if event.featured_entrants.present?
              blurb += " featuring #{event.entrants_sentence(show_count: false)}\n"
            end
          else
            "#{event.game.name}: (player count TBD)"
          end

          # List all events for the tournament just to give some context.
          embed.description = <<~TEXT
            #{event.tournament.formatted_date_range}
            #{event.tournament.formatted_location}

            #{players_blurb}
          TEXT

          embed.image = Discordrb::Webhooks::EmbedImage.new(url: event.tournament.banner_image_url) if event.tournament.banner_image_url.present?
          embed.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new(url: event.tournament.profile_image_url) if event.tournament.profile_image_url.present?

          embed.footer = DEFAULT_FOOTER
        end
      end
    end

    def weekend_briefing(game:, events:)
      post(game_channel_id(game.slug)) do |builder|
        builder.content = "## THIS WEEKEND IN #{game.name.upcase}"
        events.each do |event|
          next unless event.should_display?

          builder.add_embed do |embed|
            embed.title = "#{event.tournament.name} (#{event.tournament.formatted_day_range})"
            embed.url = "https://start.gg/#{event.tournament.slug}"

            embed.description = <<~TEXT
              #{event.tournament.formatted_date_range}
              #{event.tournament.formatted_location}
            TEXT

            embed.image = Discordrb::Webhooks::EmbedImage.new(url: event.tournament.banner_image_url) if event.tournament.banner_image_url.present?
            embed.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new(url: event.tournament.profile_image_url) if event.tournament.profile_image_url.present?

            if event.featured_entrants.present?
              embed.description += <<~TEXT

                Featuring #{event.entrants_sentence}
              TEXT
            else
              embed.description += <<~TEXT
                #{event.player_count} players
              TEXT
            end

            embed.footer = DEFAULT_FOOTER
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
          "[#{stream['name']}](#{stream['url']})"
        end
      end.compact

      stream_text = streams.blank? ? nil : <<~TEXT

        Streams:
        #{streams.join("\n")}
      TEXT

      events = tournament.events
        .filter { |e| e.start_at.in_time_zone(tournament.timezone || 'America/New_York') <= Time.now.in_time_zone(tournament.timezone || 'America/New_York') + 12.hours }
        .filter { |e| e.state != Event::STATE_COMPLETED }

      events.group_by(&:game).each do |game, events|
        next unless events.first.should_display? || (tournament.override.present? && tournament.override.include)

        post(game_channel_id(game.slug)) do |builder|
          builder.content = '## HAPPENING TODAY'
          builder.add_embed do |embed|
            embed.title = tournament.name
            embed.url = "https://start.gg/#{tournament.slug}"

            embed.description = <<~TEXT
              #{tournament.formatted_location}

              Featuring #{events.first.entrants_sentence}
              #{stream_text}
            TEXT

            embed.image = Discordrb::Webhooks::EmbedImage.new(url: tournament.banner_image_url) if tournament.banner_image_url.present?
            embed.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new(url: tournament.profile_image_url) if tournament.profile_image_url.present?

            embed.footer = DEFAULT_FOOTER
          end
        end
      end
    end

    def stream_live(tournament:, stream:)
      stream = stream.with_indifferent_access
      game = Game.find_by(twitch_name: stream[:game])
      return unless game.present?

      post(game_channel_id(game.slug)) do |builder|
        builder.content = "### #{tournament.name.upcase} STREAM IS LIVE"
        builder.add_embed do |embed|
          embed.title = stream[:name]
          embed.url = "https://twitch.tv/#{stream[:name]}"

          embed.description = <<~TEXT
            #{stream[:title]}
            #{stream[:game]}
          TEXT

          embed.image = Discordrb::Webhooks::EmbedImage.new(url: tournament.banner_image_url) if tournament.banner_image_url.present?
          embed.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new(url: tournament.profile_image_url) if tournament.profile_image_url.present?

          embed.footer = DEFAULT_FOOTER
        end
      end
    end

    def player_stream_live(event:, player:, opponent:, stream_name:)
      # post(player.discord_notification_channel) do |builder|
      post('1358137925346398398') do |builder|
        builder.content = "### SET IS LIVE: #{player.tag} vs #{opponent.tag}"
        builder.add_embed do |embed|
          embed.title = stream[:name]
          embed.url = "https://twitch.tv/#{stream_name}"

          embed.image = Discordrb::Webhooks::EmbedImage.new(url: tournament.banner_image_url) if tournament.banner_image_url.present?
          embed.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new(url: tournament.profile_image_url) if tournament.profile_image_url.present?

          embed.footer = DEFAULT_FOOTER
        end
      end
    end

    def game_channel_id(game_slug)
      Rails.application.credentials.dig(:discord, :channel_ids, game_slug)
    end

    def post(channel_id)
      instrument('post') do
        builder = Discordrb::Webhooks::Builder.new
        yield builder

        bot.send_message(
          channel_id,
          builder.content,
          false, # tts
          builder.embeds
        )
      end
    end

    def client(game_slug)
      return @clients[game_slug.to_sym] if @clients[game_slug.to_sym].present?

      @clients[game_slug.to_sym] = Discordrb::Webhooks::Client.new(url: Rails.application.credentials.dig(:discord, :webhook_urls, game_slug.to_sym))
    end

    def bot
      return @bot if @bot.present?

      @bot = Discordrb::Bot.new token: Rails.application.credentials.dig(:discord, :token)

      at_exit do
        bot.stop
      end

      @bot.run(true)
      @bot
    end

  end
end
