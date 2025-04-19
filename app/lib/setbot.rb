class Setbot < Api
  @@bot = nil

  class << self

    def run
      Rails.logger.info 'Starting Setbot...'

      if Rails.env.production?
        bot.application_command(:connect) do |event|
          StatsD.increment('setbot.command.connect')
          handle_connect_command(event:)
        end
        bot.application_command(:disconnect) do |event|
          StatsD.increment('setbot.command.disconnect')
          handle_disconnect_command(event:)
        end
      else
        bot.application_command(:connect_local) do |event|
          StatsD.increment('setbot.command.connect')
          handle_connect_command(event:)
        end
        bot.application_command(:disconnect_local) do |event|
          StatsD.increment('setbot.command.disconnect')
          handle_disconnect_command(event:)
        end
      end

      bot.string_select custom_id: custom_id('player_select') do |event|
        StatsD.increment('setbot.string_select.player_select')
        handle_player_select(event:)
      end

      bot.string_select custom_id: custom_id('delete_connection_select') do |event|
        StatsD.increment('setbot.string_select.delete_connection_select')
        handle_delete_connection_select(event:)
      end

      bot.role_select custom_id: custom_id('role_ping_select') do |event|
        StatsD.increment('setbot.role_select.role_ping_select')
        handle_role_ping_select(event:)
      end

      at_exit do
        bot.stop
      end

      bot.run
    end

    def handle_connect_command(event:)
      if PlayerSubscription.where(discord_server_id: event.server_id).count >= 5
        event.respond(
          content: 'Unable to create connection. This server already has the maximum number of connections. Remove some with `/disconnect`.',
          ephemeral: true
        )
        return
      end

      input_value = event.options['player_tag']
      return unless input_value.present?

      players = Player.tag_similar_to(input_value).limit(10).uniq

      if players.empty?
        event.respond(
          content: 'No player found for that tag. Try again.',
          ephemeral: true
        )
      else
        event.respond(ephemeral: true, wait: true) do |builder, view|
          view.row do |r|
            r.string_select(custom_id: custom_id('player_select'), placeholder: 'Choose a player', max_values: 1) do |ss|
              players.each do |player|
                ss.option(label: player.tag, value: player.id, description: player.name, emoji: { name: '👤' })
              end
            end
          end
        end
      end
    end

    def handle_disconnect_command(event:)
      subscriptions = PlayerSubscription.where(
        discord_server_id: event.server_id,
        discord_channel_id: event.channel_id
      )

      if subscriptions.empty?
        event.respond(
          content: 'No connections found for this channel. Use `/connect` to add one.',
          ephemeral: true
        )
        return
      end

      event.respond(ephemeral: true) do |builder, view|
        view.row do |r|
          r.string_select(custom_id: custom_id('delete_connection_select'), placeholder: 'Choose a connection to remove', max_values: 1) do |ss|
            subscriptions.each do |subscription|
              ss.option(label: subscription.player.tag, value: subscription.id, description: subscription.player.name, emoji: { name: '👤' })
            end
          end
        end
      end
    end

    def handle_player_select(event:)
      player = Player.find_by(id: event.values.first)

      if player.blank?
        return event.interaction.update_message(
          content: 'Unable to create connection. Please try again.',
        )
      end

      event.interaction.update_message(content: 'Loading...')

      if PlayerSubscription.find_by(
        player:,
        discord_server_id: event.server_id,
        discord_channel_id: event.channel_id
      ).present?
        return event.interaction.edit_response(
          content: "Connection for #{player.tag} already exists in this channel."
        )
      end

      if PlayerSubscription.where(discord_server_id: event.server_id).count >= 5
        return event.interaction.edit_response(
          content: 'Unable to create connection. This server already has the maximum number of connections. Remove some with `/disconnect`.'
        )
      end

      PlayerSubscription.create!(
        player:,
        discord_server_id: event.server_id,
        discord_channel_id: event.channel_id
      )

      event.interaction.edit_response(
        content: "Connection added. All streamed sets for #{player.tag} will be announced in this channel. Use `/disconnect` to remove the connection. Optionally, add a role to ping for set notifications below."
      )

      event.send_message(
        content: 'Optionally, add a role to ping for set notifications.',
        ephemeral: true
      ) do |builder, view|
        view.row do |r|
          r.role_select(custom_id: custom_id('role_ping_select'), placeholder: 'Choose a role to ping', max_values: 1)
        end
      end
    end

    def handle_delete_connection_select(event:)
      PlayerSubscription.find_by(
        id: event.values.first,
        discord_server_id: event.server_id,
        discord_channel_id: event.channel_id
      ).destroy

      event.interaction.update_message(
        content: 'Connection removed.',
        ephemeral: true
      )
    end

    def handle_role_ping_select(event:)
      subscription = PlayerSubscription.where(
        discord_server_id: event.server_id,
        discord_channel_id: event.channel_id
      ).order(created_at: :desc).limit(1).first

      subscription.discord_role_id = event.values.first.id
      subscription.save!

      event.interaction.update_message(
        content: "<@&#{event.values.first.id}> will be pinged for all set notifications for #{subscription.player.tag}.",
      )
    end

    def notify_subscriptions(event:, player:, opponent:, stream_name:, startgg_set_id:)
      StatsD.increment('setbot.notification.set_live')
      bot = Discordrb::Bot.new token: Rails.application.credentials.dig(:discord, :setbot_token)

      PlayerSubscription.where(player:).each do |subscription|
        previous_notification = Notification.where(
          notifiable: subscription,
          notification_type: Notification::TYPE_SETBOT_SET_LIVE,
          platform: Notification::PLATFORM_DISCORD,
          success: true
        ).order(sent_at: :desc).first

        metadata = previous_notification&.metadata&.with_indifferent_access

        next if previous_notification.present? &&
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

              content = "### SET IS LIVE: #{player.tag} vs. #{opponent.tag}"

              if subscription.discord_role_id.present?
                content += "\n\n<@&#{subscription.discord_role_id}>"
              end

              builder.content = content

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
      if Rails.env.production?
        bot.get_application_commands.each(&:delete)
        bot.register_application_command(:connect, 'Add a SetBot connection', default_permission: 1 << 5) do |cmd|
          cmd.string('player_tag', 'The tag of the player to notify this channel about.', required: true)
        end
        bot.register_application_command(:disconnect, 'Remove a SetBot connection', default_permission: 1 << 5)
        Rails.logger.info 'Global commands successfully registered.'
      else
        server_id = '1260259175586467840'
        bot.get_application_commands(server_id:).each(&:delete)
        bot.register_application_command(:connect_local, 'Add a SetBot connection', server_id:, default_permission: 1 << 5) do |cmd|
          cmd.string('player_tag', 'The tag of the player to notify this channel about.', required: true)
        end
        bot.register_application_command(:disconnect_local, 'Remove a SetBot connection', server_id:, default_permission: 1 << 5)
        Rails.logger.info 'Server-specific commands successfully registered.'
      end
    end

    def custom_id(str)
      "#{str}_#{Rails.env}"
    end

    def bot
      return @@bot if @@bot.present?

      @@bot = Discordrb::Bot.new token: Rails.application.credentials.dig(:discord, :setbot_token)
    end

  end

end
