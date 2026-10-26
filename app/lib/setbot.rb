# TODO: This shouldn't really extend Gateway as is, but it gives access to
# `instrument` which happens to be useful here. This class should probably get
# converted into a module with a gateway, or reuse the Discord gateway somehow.
class Setbot < ::Gateway
  SMASHRADAR_SERVER_ID = '1260259175586467840'

  @bot = nil

  class << self

    def run
      Rails.logger.info 'Starting Setbot...'

      if Rails.env.development?
        register_commands

        at_exit { delete_commands(server_id: SMASHRADAR_SERVER_ID) }
      end

      bot.application_command(Rails.env.production? ? :subscribe : :subscribe_dev) do |event|
        StatsD.increment('setbot.command.subscribe')
        with_error_reporting { handle_subscribe_command(event:) }
      end

      bot.application_command(Rails.env.production? ? :unsubscribe : :unsubscribe_dev) do |event|
        StatsD.increment('setbot.command.unsubscribe')
        with_error_reporting { handle_unsubscribe_command(event:) }
      end

      bot.string_select custom_id: custom_id('player_select') do |event|
        StatsD.increment('setbot.string_select.player_select')
        with_error_reporting { handle_player_select(event:) }
      end

      bot.string_select custom_id: custom_id('delete_subscription_select') do |event|
        StatsD.increment('setbot.string_select.delete_subscription_select')
        with_error_reporting { handle_delete_subscription_select(event:) }
      end

      bot.role_select custom_id: custom_id('role_ping_select') do |event|
        StatsD.increment('setbot.role_select.role_ping_select')
        with_error_reporting { handle_role_ping_select(event:) }
      end

      at_exit do
        bot.stop
      end

      bot.run
    end

    # discordrb runs each event handler in its own thread and rescues any
    # errors, only logging them, so Sentry never sees them. Report them
    # explicitly and re-raise so discordrb still logs them.
    def with_error_reporting
      yield
    rescue => e
      Sentry.capture_exception(e)
      raise
    end

    def handle_subscribe_command(event:)
      if PlayerSubscription.where(discord_server_id: event.server_id).count >= player_subscription_limit(event.server_id)
        event.respond(
          content: 'Unable to create subscription. This server already has the maximum number of subscriptions. Remove some with `/unsubscribe`.',
          ephemeral: true
        )
        return
      end

      input_value = event.options['player_tag']
      return unless input_value.present?

      startgg_slug = input_value.match(%r{/user/([^/]+)})
      parrygg_slug = input_value.match(%r{/profile/([^/]+)})
      players = if startgg_slug.present?
        Player.where(provider: Startgg::Provider::PROVIDER_NAME, provider_user_slug: startgg_slug[1])
      elsif parrygg_slug.present?
        Player.where(provider: Parrygg::Provider::PROVIDER_NAME, provider_user_id: parrygg_slug[1])
      else
        Player.tag_similar_to(input_value).limit(10).uniq
      end

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
                description = player.name || (player.twitter_username.present? ? "@#{player.twitter_username}" : nil)
                description = description.present? ? "#{description} | " : ''
                description += Provider.provider(player.provider)::FORMATTED_NAME
                ss.option(label: player.tag, value: player.id, description:, emoji: { name: '👤' })
              end
            end
          end
        end
      end
    end

    def handle_unsubscribe_command(event:)
      subscriptions = PlayerSubscription.where(
        discord_server_id: event.server_id,
        discord_channel_id: event.channel_id
      )

      if subscriptions.empty?
        event.respond(
          content: 'No subscriptions found for this channel. Use `/subscribe` to add one.',
          ephemeral: true
        )
        return
      end

      event.respond(ephemeral: true) do |builder, view|
        view.row do |r|
          r.string_select(custom_id: custom_id('delete_subscription_select'), placeholder: 'Choose a subscription to remove', max_values: 1) do |ss|
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
          content: 'Unable to create subscription. Please try again.'
        )
      end

      event.interaction.update_message(content: 'Loading...')

      if PlayerSubscription.find_by(
        player:,
        discord_server_id: event.server_id,
        discord_channel_id: event.channel_id
      ).present?
        return event.interaction.edit_response(
          content: "Subscription for #{player.tag} already exists in this channel."
        )
      end

      if PlayerSubscription.where(discord_server_id: event.server_id).count >= player_subscription_limit(event.server_id)
        return event.interaction.edit_response(
          content: 'Unable to create subscription. This server already has the maximum number of subscriptions. Remove some with `/unsubscribe`.'
        )
      end

      PlayerSubscription.create!(
        player:,
        discord_server_id: event.server_id,
        discord_server_name: event.server.name,
        discord_channel_id: event.channel_id
      )

      event.interaction.edit_response(
        content: "Subscription added. All streamed sets for #{player.tag} will be announced in this channel. Use `/unsubscribe` to remove the subscription. Optionally, add a role to ping for set notifications below."
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

    def handle_delete_subscription_select(event:)
      PlayerSubscription.find_by(
        id: event.values.first,
        discord_server_id: event.server_id,
        discord_channel_id: event.channel_id
      ).destroy

      event.interaction.update_message(
        content: 'Subscription removed.',
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
        content: "<@&#{event.values.first.id}> will be pinged for all set notifications for #{subscription.player.tag}."
      )
    end

    def notify_subscriptions(set:)
      [set.entrant1, set.entrant2].each do |entrant|
        opponent = ([set.entrant1, set.entrant2] - [entrant]).first
        next unless opponent.present?

        [entrant.player, entrant.player2].compact.each do |player|
          PlayerSubscription.where(player:).each do |subscription|
            previous_notifications = Notification.where(
              notifiable: subscription,
              notification_type: Notification::TYPE_SETBOT_SET_LIVE,
              platform: Notification::PLATFORM_DISCORD,
              success: true
            ).order(sent_at: :desc).limit(10)

            next if previous_notifications.any? do |notification|
              metadata = notification&.metadata&.with_indifferent_access
              metadata[:provider_set_id]&.to_s == set.provider_set_id
            end

            StatsD.increment('setbot.notification.set_live')

            begin
              Notification.send_notification(
                subscription,
                type: Notification::TYPE_SETBOT_SET_LIVE,
                platform: Notification::PLATFORM_DISCORD,
                metadata: {
                  provider_set_id: set.provider_set_id
                }
              ) do |subscription|
                instrument('post') do
                  builder = Discordrb::Webhooks::Builder.new

                  content = "### SET IS LIVE: #{entrant.tag} vs. #{opponent.tag}"

                  content += "\n\n<@&#{subscription.discord_role_id}>" if subscription.discord_role_id.present?

                  builder.content = content

                  builder.add_embed do |embed|
                    embed.title = set.stream.channel
                    embed.url = set.stream.url

                    embed.description = "#{set.event.tournament.name}\n(#{set.event.game.twitch_name})"

                    embed.image = Discordrb::Webhooks::EmbedImage.new(url: set.event.tournament.banner_image_url) if set.event.tournament.banner_image_url.present?
                    embed.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new(url: set.event.tournament.profile_image_url) if set.event.tournament.profile_image_url.present?

                    embed.footer = Discord::Gateway::DEFAULT_FOOTER
                  end

                  bot.send_message(
                    subscription.discord_channel_id,
                    builder.content,
                    false, # tts
                    builder.embeds
                  )
                end
              end
            rescue Discordrb::Errors::UnknownChannel
              Rails.logger.info("Deleting subscription with missing discord channel: #{subscription.attributes.to_json}")
              subscription.destroy!
            rescue => e
              Rails.logger.error("Error when attempting to send SetBot notification for subscription #{subscription.id}: #{e.message}")
              Sentry.capture_exception(e)
            end

          end
        end
      end
    end

    def register_commands
      server_id = Rails.env.production? ? nil : SMASHRADAR_SERVER_ID
      Rails.logger.info('Registering application commands...')

      register_or_edit_application_command(
        Rails.env.production? ? :subscribe : :subscribe_dev,
        description: 'Add a Setbot subscription',
        default_member_permissions: 1 << 5,
        server_id:
      ) do |cmd|
        cmd.string('player_tag', 'The tag of the player to notify this channel about, or a link to their start.gg profile.', required: true)
      end

      register_or_edit_application_command(
        Rails.env.production? ? :unsubscribe : :unsubscribe_dev,
        description: 'Remove a Setbot subscription',
        default_member_permissions: 1 << 5,
        server_id:
      )

      Rails.logger.info 'Commands successfully registered.'
    end

    def register_or_edit_application_command(name, description:, default_member_permissions:, server_id:)
      existing_commands = bot.get_application_commands(server_id:).reduce({}.with_indifferent_access) do |commands, command|
        commands[command.name] = command
        commands
      end

      if existing_commands[name]
        bot.edit_application_command(existing_commands[name].id, description:, default_member_permissions:, server_id:) do |cmd|
          yield(cmd) if block_given?
        end
      else
        bot.register_application_command(name, description, default_member_permissions:, server_id:) do |cmd|
          yield(cmd) if block_given?
        end
      end
    end

    def delete_commands(server_id: nil)
      Rails.logger.info("Deleting application commands for server #{server_id}...")
      bot.get_application_commands(server_id:).each(&:delete)
    end

    def custom_id(str)
      "#{str}_#{Rails.env}"
    end

    def player_subscription_limit(discord_server_id)
      DiscordServer.find_by(discord_server_id:)&.player_subscription_limit || 5
    end

    def bot
      @bot ||= Discordrb::Bot.new token: Rails.application.credentials.dig(:discord, :setbot_token)
    end

  end

end
