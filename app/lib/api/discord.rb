module Api
  class Discord
    extend Instrumentable

    @clients = {}
    @bot = nil

    DEFAULT_FOOTER = Discordrb::Webhooks::EmbedFooter.new(
      text: 'smashradar.com',
      icon_url: 'https://smashradar.com/favicon.png'
    )

    class << self

      def event_added(event)
        post(game_channel_id(event.game_slug)) do |builder|
          builder.content = '## NEW EVENT ADDED'
          builder.add_embed do |embed|
            embed.title = if event.tournament_has_other_events_for_game?
              "#{event.tournament.name}: #{event.name}"
            else
              event.tournament.name
            end

            embed.url = event.tournament.url

            players_blurb = if event.entrant_count.present? && event.entrant_count > 0
              blurb = "#{event.entrant_count} players"

              blurb += " featuring #{event.entrants_sentence(show_count: false)}\n" if event.featured_entrants.present?

              blurb
            else
              "#{event.game.name}: (player count TBD)"
            end

            embed.description = <<~TEXT
              #{event.game.twitch_name}
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
          events.group_by(&:tournament).each do |tournament, events|

            builder.add_embed do |embed|
              embed.title = "#{tournament.name} (#{tournament.formatted_day_range})"
              embed.url = tournament.url

              embed.description = <<~TEXT
                #{tournament.formatted_date_range}
                #{tournament.formatted_location}
              TEXT

              embed.image = Discordrb::Webhooks::EmbedImage.new(url: tournament.banner_image_url) if tournament.banner_image_url.present?
              embed.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new(url: tournament.profile_image_url) if tournament.profile_image_url.present?

              event_blurbs = events.sort_by(&:entrant_count).reverse.map do |event|
                if event.featured_entrants.present?
                  prefix = event.tournament_has_other_events_for_game? ? "#{event.name.upcase} featuring" : 'Featuring'
                  "#{prefix} #{event.entrants_sentence}"
                else
                  prefix = event.tournament_has_other_events_for_game? ? "#{event.name.upcase}: " : ''
                  "#{prefix}#{event.entrant_count} players"
                end
              end

              embed.description += <<~TEXT

                #{event_blurbs.join("\n\n")}
              TEXT

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
          .filter { |e| e.start_at <= Time.now + 12.hours }
          .filter { |e| e.state != Event::STATE_COMPLETED }
          .filter { |e| e.should_display? }
          .sort_by { |e| e.entrant_count || 0 }
          .reverse

        events.group_by(&:game).each do |game, events|
          post(game_channel_id(game.slug)) do |builder|
            builder.content = '## HAPPENING TODAY'
            builder.add_embed do |embed|
              embed.title = tournament.name
              embed.url = tournament.url

              event_blurbs = events.map do |event|
                "#{event.display_name.upcase} featuring #{event.entrants_sentence}"
              end

              embed.description = <<~TEXT
                #{tournament.formatted_location}

                #{event_blurbs.join("\n\n")}
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

      def player_set_live(event:, player:, opponent:, stream_name:)
        post(sets_channel_id(event.game.slug)) do |builder|
          builder.content = "### SET IS LIVE: #{player.tag} vs #{opponent.tag}"

          builder.add_embed do |embed|
            embed.title = stream_name
            embed.url = "https://twitch.tv/#{stream_name}"

            embed.description = <<~TEXT
              #{event.tournament.name}
              #{event.game.twitch_name}
            TEXT

            embed.image = Discordrb::Webhooks::EmbedImage.new(url: event.tournament.banner_image_url) if event.tournament.banner_image_url.present?
            embed.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new(url: event.tournament.profile_image_url) if event.tournament.profile_image_url.present?

            embed.footer = DEFAULT_FOOTER
          end
        end
      end

      def game_channel_id(game_slug)
        Rails.application.credentials.dig(:discord, :channel_ids, game_slug)
      end

      def sets_channel_id(game_slug)
        Rails.application.credentials.dig(:discord, :channel_ids, :sets, game_slug)
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

      def bot
        return @bot if @bot.present?

        @bot = Discordrb::Bot.new token: Rails.application.credentials.dig(:discord, :token)

        at_exit do
          @bot.stop
        end

        @bot.run(true)
        @bot
      end

    end
  end
end
