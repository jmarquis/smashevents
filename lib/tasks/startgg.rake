namespace :startgg do
  task sync: [:environment, 'startgg:sync_tournaments', 'startgg:sync_overrides', 'startgg:sync_entrants']

  task sync_tournaments: [:environment] do
    num_analyzed = 0
    num_imported = 0
    num_updated = 0

    puts 'Starting tournament sync...'

    (1..1000).each do |page|
      tournaments = Startgg.with_retries(5, batch_size: 15) do |batch_size|
        puts "Fetching page #{page} of tournaments..."
        Startgg.tournaments(batch_size:, page:, after_date: Time.now - 7.days)
      end

      puts "#{tournaments.count} tournaments found. Analyzing..."
      num_analyzed += tournaments.count
      break if tournaments.count.zero?

      tournaments.each do |data|
        tournament, events = Tournament.from_startgg_tournament(data)

        next if events.blank?
        next if tournament.exclude?
        next unless events.any?(&:should_ingest?) || tournament.should_ingest?

        if tournament.persisted?
          if tournament.changed? || events.any?(&:changed?)
            tournament.save!
            events.each(&:save!)

            StatsD.increment('startgg.tournament_updated')
            updated_log(tournament, events)
            num_updated += 1
          end
        else
          tournament.save!

          StatsD.increment('startgg.tournament_added')
          event_blurbs = tournament.events.map { |event| "#{event.game.slug}: #{event.player_count}" }
          puts "+ #{tournament.slug}: #{event_blurbs.join(', ')}"
        end
      end

      sleep 1
    end

    puts '----------------------------------'
    puts "Analyzed: #{num_analyzed}"
    puts "Imported: #{num_imported}"
    puts "Updated: #{num_updated}"
  end

  task sync_overrides: [:environment] do
    num_analyzed = 0
    num_imported = 0
    num_updated = 0
    num_deleted = 0

    puts 'Starting override sync...'

    TournamentOverride.all.each do |override|
      if !override.include
        tournament = Tournament.find_by(slug: override.slug)
        if tournament.present?
          puts "- #{tournament.slug}"

          StatsD.increment('startgg.tournament_deleted')
          tournament.destroy
          num_deleted += 1
        end

        next
      end

      tournament = Tournament.find_by(slug: override.slug)
      next if tournament.present? && tournament.past?

      num_analyzed += 1

      data = Startgg.with_retries(5) do
        puts "Fetching tournament #{override.slug}..."
        Startgg.tournament(slug: override.slug)
      end

      tournament, events = Tournament.from_startgg_tournament(data)

      if tournament.persisted?
        if tournament.changed? || events.any?(&:changed?)
          tournament.save!

          StatsD.increment('startgg.tournament_updated')
          updated_log(tournament, events)
          num_updated += 1
        end
      else
        tournament.save!

        StatsD.increment('startgg.tournament_added')
        event_blurbs = tournament.events.map { |event| "#{event.game.slug}: #{event.player_count}" }
        puts "+ #{tournament.slug}: #{event_blurbs.join(',')}"
        num_imported += 1
      end

      # Update override slug to match actual tournament slug
      override.slug = tournament.slug
      override.save!

      sleep 1
    end

    puts '----------------------------------'
    puts "Analyzed: #{num_analyzed}"
    puts "Imported: #{num_imported}"
    puts "Updated: #{num_updated}"
    puts "Deleted: #{num_deleted}"
  end

  task :sync_entrants, [:tournament_id] => [:environment] do |task, args|
    num_events = 0

    puts 'Starting entrant sync...'

    tournaments = args[:tournament_id].present? ? [Tournament.find(args[:tournament_id])] : Tournament.upcoming

    tournaments.each do |tournament|
      events = args[:tournament_id].present? ? tournament.events : tournament.events.should_sync

      events.each do |event|
        event.sync_entrants

        num_events += 1
        if num_events % 50 == 0
          puts "Scanned #{num_events} events so far..."
        end
      end
    end

    puts 'Entrant sync complete.'
  end

  task scan_stream_sets: [:environment] do
    Tournament.should_display.live.each do |tournament|
      tournament.events.each do |event|
        next if event.completed?

        (1..1000).each do |page|
          sets = Startgg.with_retries(5, batch_size: 50) do |batch_size|
            puts "Fetching sets for #{tournament.slug} #{event.game.slug}..."

            # TODO: Filter by set state?
            Startgg.sets(event.startgg_id, batch_size:, page:, updated_after: event.sets_synced_at)
          end

          puts "Found #{sets.count} sets. Analyzing..."
          break if sets.count.zero?

          sets.each do |set|

            # Most sets don't have a stream, so this filters a ton.
            next unless set.stream.present?
            next unless set.stream.stream_source == Tournament::STREAM_SOURCE_TWITCH

            # We only care about currently ongoing sets.
            next unless set.started_at.present?
            next unless set.completed_at.blank?

            # If the player records aren't set, we can't do anything.
            next unless set.slots&.first&.entrant&.participants&.first&.player&.present?
            next unless set.slots&.second&.entrant&.participants&.first&.player&.present?

            players = Player.where(startgg_id: set.slots.first.entrant.participants.map(&:id))

            # Make sure we have players we want to notify about.
            next unless players.any?(&:discord_notification_channel)

            players.each do |player|

              next unless player.discord_notification_channel.present?

              previous_notification = Notification.find_by(
                notifiable: player,
                notification_type: Notification::TYPE_PLAYER_STREAM_LIVE,
                platform: Notification::PLATFORM_DISCORD,
                success: true
              )

              next if previous_notification.present? && previous_notification.metadata[:startgg_set_id] == set.id

              Notification.send_notification(
                player,
                notification_type: Notification::TYPE_PLAYER_STREAM_LIVE,
                platform: Notification::PLATFORM_DISCORD,
                metadata: { startgg_set_id: set.id }
              ) do |player|
                Discord.player_stream_live(
                  event:,
                  player:,
                  opponent: (players - [player]).first,
                  stream_name: set.stream.stream_name
                )
              end

            end

          end

          sleep 1
        end

        event.sets_synced_at = Time.now
        event.save!
      end
    end
  end

  private

  def updated_log(tournament, events)
    tournament_changes = tournament.saved_changes.reject { |k| k == 'updated_at' }
    puts "~ #{tournament.slug}: #{tournament_changes}"
    events.each do |event|
      event_changes = event.saved_changes.reject { |k| k == 'updated_at' }
      next if event_changes.blank?

      puts "  ~ #{event.game.slug.upcase}: #{event_changes}"
    end
  end

  def puts_dev(msg)
    puts msg if Rails.env.development?
  end
end
