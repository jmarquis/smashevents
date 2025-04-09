class Setbot < Api
  @@bot = nil

  class << self

    def run
      bot.application_command :connect do |event|
        event.show_modal(title: 'Add SetBot connection', custom_id: 'add_connection_modal') do |modal|
          modal.row do |row|
            row.text_input(
              style: :short,
              custom_id: 'player_input',
              label: 'Player tag',
              required: true,
              min_length: 2,
              placeholder: 'Type exact player tag'
            )
          end
        end
      end

      bot.modal_submit custom_id: 'add_connection_modal' do |event|
        input_value = event.value('player_input')
        return unless input_value.present?

        players = Player.tag_similar_to(input_value).limit(10).uniq

        if players.empty?
          event.respond(
            content: 'No player found for that tag. Try again.',
            ephemeral: true
          )
        elsif players.count == 1
          if PlayerSubscription.find_by(
            id: players.first,
            discord_server_id: event.server_id,
            discord_channel_id: event.channel_id
          ).present?
            event.respond(
              content: "Connection for #{player.first.tag} already exists in this channel.",
              ephemeral: true
            )
          end

          PlayerSubscription.create!(
            player: players.first,
            discord_server_id: event.server_id,
            discord_channel_id: event.channel_id
          )

          event.respond(
            content: "Connection added. All streamed sets for #{players.first.tag} will be announced in this channel. Use `/disconnect` to remove the connection.",
            ephemeral: true
          )
        else
          event.respond(ephemeral: true) do |builder, view|
            view.row do |r|
              r.string_select(custom_id: 'player_select', placeholder: 'Choose a player', max_values: 1) do |ss|
                players.each do |player|
                  ss.option(label: player.tag, value: player.id, description: player.name, emoji: { name: '👤' })
                end
              end
            end
          end
        end
      end

      bot.string_select custom_id: 'player_select' do |event|
        player = Player.find(event.values.first)

        if player.blank?
          event.respond(
            content: 'Unable to create connection. Please try again.',
            ephemeral: true
          )
          break
        end

        if PlayerSubscription.find_by(
          id: players.first,
          discord_server_id: event.server_id,
          discord_channel_id: event.channel_id
        ).present?
          event.respond(
            content: "Connection for #{player.tag} already exists in this channel.",
            ephemeral: true
          )
        end

        if PlayerSubscription.where(discord_server_id: event.server_id).count >= 5
          event.respond(
            content: 'Unable to create connection. This server already has the maximum number of connections. Remove some with `/disconnect`.',
            ephemeral: true
          )
          break
        end

        PlayerSubscription.create!(
          player:,
          discord_server_id: event.server_id,
          discord_channel_id: event.channel_id
        )

        event.respond(
          content: "Connection added. All streamed sets for #{player.tag} will be announced in this channel. Use `/disconnect` to remove the connection.",
          ephemeral: true
        )
      end

      bot.application_command :disconnect do |event|
        subscriptions = PlayerSubscription.where(
          discord_server_id: event.server_id,
          discord_channel_id: event.channel_id
        )

        if subscriptions.empty?
          event.respond(
            content: 'No connections found for this channel. Use `/connect` to add one.',
            ephemeral: true
          )
          break
        end

        event.respond(ephemeral: true) do |builder, view|
          view.row do |r|
            r.string_select(custom_id: 'connection_select', placeholder: 'Choose a connection to remove', max_values: 1) do |ss|
              subscriptions.each do |subscription|
                ss.option(label: subscription.player.tag, value: subscription.id, description: subscription.player.name, emoji: { name: '👤' })
              end
            end
          end
        end
      end

      bot.string_select custom_id: 'connection_select' do |event|
        PlayerSubscription.find_by(
          id: event.values.first,
          discord_server_id: event.server_id,
          discord_channel_id: event.channel_id
        ).destroy

        event.respond(
          content: 'Connection removed.',
          ephemeral: true
        )
      end

      at_exit do
        bot.stop
      end

      bot.run
    end

    def notify_subscriptions(event:, player:, opponent:, stream_name:, startgg_set_id:)
      bot = Discordrb::Bot.new token: Rails.application.credentials.dig(:discord, :setbot_token)

      PlayerSubscription.where(player:).each do |subscription|
        previous_notification = Notification.where(
          notifiable: subscription,
          notification_type: Notification::TYPE_SETBOT_SET_LIVE,
          platform: Notification::PLATFORM_DISCORD,
          success: true
        ).order(sent_at: :desc).first

        metadata = previous_notification&.metadata&.with_indifferent_access

        next if
          previous_notification.present? &&
          metadata[:discord_server_id]&.to_s == subscription.discord_server_id.to_s &&
          metadata[:discord_channel_id]&.to_s == subscription.discord_channel_id.to_s &&
          metadata[:startgg_set_id]&.to_s == startgg_set_id

        begin
          Notification.send_notification(
            subscription,
            type: Notification::TYPE_SETBOT_SET_LIVE,
            platform: Notification::PLATFORM_DISCORD,
            metadata: {
              discord_server_id: subscription.discord_server_id,
              discord_channel_id: subscription.discord_channel_id,
              startgg_set_id:
            }
          ) do |subscription|
            instrument('post') do
              builder = Discordrb::Webhooks::Builder.new

              builder.content = "### SET IS LIVE: #{player.tag} vs. #{opponent.tag}"
              builder.add_embed do |embed|
                embed.title = stream_name
                embed.url = "https://twitch.tv/#{stream_name}"

                embed.description = "#{event.tournament.name}\n(#{event.game.twitch_name})"

                embed.image = Discordrb::Webhooks::EmbedImage.new(url: event.tournament.banner_image_url) if event.tournament.banner_image_url.present?
                embed.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new(url: event.tournament.profile_image_url) if event.tournament.profile_image_url.present?

                embed.footer = Discord::DEFAULT_FOOTER
              end

              bot.send_message(
                subscription.discord_channel_id,
                builder.content,
                false, # tts
                builder.embeds
              )
            end
          rescue => e
            Rails.logger.error("Error when attempting to send SetBot notification for subscription #{subscription.id}: #{e.message}")
          end
        end
      end
    end

    def register_commands
      bot.get_application_commands.each(&:delete)
      bot.register_application_command(:connect, 'Add a SetBot connection', default_permission: 1 << 5)
      bot.register_application_command(:disconnect, 'Remove a SetBot connection', default_permission: 1 << 5)
    end

    def register_test_commands
      server_id = '1260259175586467840'
      bot.get_application_commands(server_id:).each(&:delete)
      bot.register_application_command(:connect, 'Add a SetBot connection', server_id:, default_permission: 1 << 5)
      bot.register_application_command(:disconnect, 'Remove a SetBot connection', server_id:, default_permission: 1 << 5)
    end

    def bot
      return @@bot if @@bot.present?

      @@bot = Discordrb::Bot.new token: Rails.application.credentials.dig(:discord, :setbot_token)
    end

  end

end
