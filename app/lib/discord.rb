class Discord
  @clients = {}

  DEFAULT_FOOTER = Discordrb::Webhooks::EmbedFooter.new(
    text: 'smashevents.gg',
    icon_url: 'https://smashevents.gg/favicon.png'
  )

  class << self

    def tournament_added(tournament)
      tournament.events.group_by(&:game).each do |game_slug, events|
        next unless events.first.should_display?

        client(game_slug).execute do |builder|
          builder.content = '## NEW TOURNAMENT ADDED'
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

            embed.image = Discordrb::Webhooks::EmbedImage.new(url: tournament.banner_image_url) if tournament.banner_image_url.present?
            embed.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new(url: tournament.profile_image_url) if tournament.profile_image_url.present?

            embed.footer = DEFAULT_FOOTER
          end
        end
      end
    end

    def weekend_briefing(game:, events:)
      client(game.slug).execute do |builder|
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

                Featuring #{[*event.featured_players, "#{(event.player_count - event.featured_players.count)} more!"].to_sentence}
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

        player_blurb = if events.first.featured_players.present?
          "Featuring #{[*events.first.featured_players, "#{(events.first.player_count - events.first.featured_players.count)} more!"].to_sentence}"
        else
          "Featuring #{events.first.player_count} players!"
        end

        client(game_slug).execute do |builder|
          builder.content = '## HAPPENING TODAY'
          builder.add_embed do |embed|
            embed.title = tournament.name
            embed.url = "https://start.gg/#{tournament.slug}"

            embed.description = <<~TEXT
              #{tournament.formatted_location}

              #{player_blurb}
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

      client(game.slug).execute do |builder|
        builder.content = "### #{tournament.name.upcase}** STREAM IS LIVE"
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

    def client(game_slug)
      return @clients[game_slug.to_sym] if @clients[game_slug.to_sym].present?

      @clients[game_slug.to_sym] = Discordrb::Webhooks::Client.new(url: Rails.application.credentials.dig(:discord, :webhook_urls, game_slug.to_sym))
    end

  end
end
