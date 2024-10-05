class Discord
  @clients = {}

  DEFAULT_FOOTER = Discordrb::Webhooks::EmbedFooter.new(
    text: 'smashevents.gg',
    icon_url: 'https://smashevents.gg/favicon.png'
  )

  class << self

    def event_added(game_slug, event)
      post(game_slug) do |builder|
        builder.content = '## NEW EVENT ADDED'
        builder.add_embed do |embed|
          embed.title = event.tournament.name
          embed.url = "https://start.gg/#{event.tournament.slug}"

          # List all events for the tournament just to give some context.
          embed.description = <<~TEXT
            #{event.tournament.formatted_date_range}
            #{event.tournament.formatted_location}

            #{event.tournament.events.sort_by(&:player_count).reverse.map { |event|
              if event.player_count.present? && event.player_count > 0
                "#{Game.by_slug(event.game).name}: #{event.player_count} players"
              else
                "#{Game.by_slug(event.game).name}: (player count TBD)"
              end
            }.join("\n")}
          TEXT

          embed.image = Discordrb::Webhooks::EmbedImage.new(url: event.tournament.banner_image_url) if event.tournament.banner_image_url.present?
          embed.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new(url: event.tournament.profile_image_url) if event.tournament.profile_image_url.present?

          embed.footer = DEFAULT_FOOTER
        end
      end
    end

    def weekend_briefing(game:, events:)
      post(game.slug) do |builder|
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

            if event.featured_players.present?
              embed.description += <<~TEXT

                Featuring #{event.players_sentence}
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
          "[#{stream['name']}](#{Youtube.channel_url(stream['name'])}/live)"
        end
      end.compact

      stream_text = streams.blank? ? nil : <<~TEXT

        Streams:
        #{streams.join("\n")}
      TEXT

      tournament.events.group_by(&:game).each do |game_slug, events|
        next unless events.first.should_display? || (tournament.override.present? && tournament.override.include)

        post(game_slug) do |builder|
          builder.content = '## HAPPENING TODAY'
          builder.add_embed do |embed|
            embed.title = tournament.name
            embed.url = "https://start.gg/#{tournament.slug}"

            embed.description = <<~TEXT
              #{tournament.formatted_location}

              Featuring #{events.first.players_sentence}
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
      game = Game.by_twitch_name(stream[:game])
      return unless game.present?

      post(game.slug) do |builder|
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

    def post(game_slug)
      StatsD.measure('discord.post') do
        client(game_slug).execute do |builder|
          yield builder
        end
      end
    end

    def client(game_slug)
      return @clients[game_slug.to_sym] if @clients[game_slug.to_sym].present?

      @clients[game_slug.to_sym] = Discordrb::Webhooks::Client.new(url: Rails.application.credentials.dig(:discord, :webhook_urls, game_slug.to_sym))
    end

  end
end
