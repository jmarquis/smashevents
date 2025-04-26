namespace :startgg do
  task sync: [:environment, 'startgg:sync_tournaments', 'startgg:sync_overrides', 'startgg:sync_entrants']

  task sync_tournaments: [:environment] do
    stats = {
      analyzed: 0,
      imported: 0,
      updated: 0
    }
    start_time = Time.now
    last_sync = Rails.cache.read('startgg/last_tournament_sync')

    Rails.logger.info "Starting tournament sync (last sync: #{last_sync.inspect})..."

    (1..1000).each do |page|
      tournaments = Startgg.with_retries(5, batch_size: 15) do |batch_size|
        Rails.logger.info "Fetching page #{page} of tournaments..."
        Startgg.tournaments(batch_size:, page:, after_date: Time.now - 7.days, updated_after: last_sync.present? ? last_sync - 5.minutes : 1.year.ago)
      end

      break if tournaments.count.zero?
      Rails.logger.info "#{tournaments.count} tournaments found. Analyzing..."
      stats[:analyzed] += tournaments.count

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
            stats[:updated] += 1
          end
        else
          tournament.save!

          stats[:imported] += 1
          StatsD.increment('startgg.tournament_added')
          event_blurbs = tournament.events.map { |event| "#{event.game.slug}: #{event.player_count}" }
          Rails.logger.info "+ #{tournament.slug}: #{event_blurbs.join(', ')}"
        end
      end

      break if tournaments.count < 15

      sleep 1
    end

    Rails.cache.write('startgg/last_tournament_sync', start_time, expires_in: 1.day)

    Rails.logger.info "Tournament sync complete. #{stats.to_json}"
  end

  task sync_overrides: [:environment] do
    stats = {
      analyzed: 0,
      imported: 0,
      updated: 0,
      deleted: 0
    }

    Rails.logger.info 'Starting override sync...'

    TournamentOverride.all.each do |override|
      if !override.include
        tournament = Tournament.find_by(slug: override.slug)
        if tournament.present?
          Rails.logger.info "- #{tournament.slug}"

          StatsD.increment('startgg.tournament_deleted')
          tournament.destroy
          stats[:deleted] += 1
        end

        next
      end

      tournament = Tournament.find_by(slug: override.slug)
      next if tournament.present? && tournament.past?

      stats[:analyzed] += 1

      data = Startgg.with_retries(5) do
        Rails.logger.info "Fetching tournament #{override.slug}..."
        Startgg.tournament(slug: override.slug)
      end

      tournament, events = Tournament.from_startgg_tournament(data)

      if tournament.persisted?
        if tournament.changed? || events.any?(&:changed?)
          tournament.save!

          StatsD.increment('startgg.tournament_updated')
          updated_log(tournament, events)
          stats[:updated] += 1
        end
      else
        tournament.save!

        StatsD.increment('startgg.tournament_added')
        event_blurbs = tournament.events.map { |event| "#{event.game.slug}: #{event.player_count}" }
        Rails.logger.info "+ #{tournament.slug}: #{event_blurbs.join(',')}"
        stats[:imported] += 1
      end

      # Update override slug to match actual tournament slug
      override.slug = tournament.slug
      override.save!

      sleep 1
    end

    Rails.logger.info "Tournament override sync complete. #{stats.to_json}"
  end

  task :sync_entrants, [:tournament_id] => [:environment] do |task, args|
    num_events = 0
    stats = {
      created: 0,
      updated: 0,
      deleted: 0
    }

    Rails.logger.info 'Starting entrant sync...'

    tournaments = args[:tournament_id].present? ? [Tournament.find(args[:tournament_id])] : Tournament.upcoming

    tournaments.each do |tournament|
      events = args[:tournament_id].present? ? tournament.events : tournament.events.should_sync_entrants

      events.each do |event|
        stats = event.sync_entrants.reduce(stats) do |stats, (key, total)|
          stats[key] += total
          stats
        end

        num_events += 1
        if num_events % 50 == 0
          Rails.logger.info "Scanned #{num_events} events so far..."
        end
      end
    end

    Rails.logger.info "Entrant sync complete. #{stats.to_json}"
  end

  task scan_sets: [:environment] do
    Tournament.should_display.live.each do |tournament|
      tournament.events.each do |event|
        next if event.completed?

        start_time = Time.now
        (1..1000).each do |page|
          sets = Startgg.with_retries(5, batch_size: 50) do |batch_size|
            Rails.logger.debug "Fetching sets for #{tournament.slug} #{event.game.slug}..."

            Startgg.sets(event.startgg_id, batch_size:, page:, updated_after: event.sets_synced_at.present? ? event.sets_synced_at - 5.seconds : 1.hour.ago)
          end

          break if sets.count.zero?
          Rails.logger.info "Found #{sets.count} updated sets for #{tournament.slug} #{event.game.slug}. Analyzing..."

          sets.each do |set|

            if set.state == Event::SET_STATE_IN_PROGRESS
              # Most sets don't have a stream, so this filters a ton.
              next unless set.stream.present?
              next unless set.stream.stream_source.downcase == Tournament::STREAM_SOURCE_TWITCH

              # We only care about currently ongoing sets.
              next unless set.started_at.present?
              next unless set.completed_at.blank?

              # If the player records aren't set, we can't do anything.
              next unless set.slots&.first&.entrant&.participants&.first&.player&.present?
              next unless set.slots&.second&.entrant&.participants&.first&.player&.present?

              players = Player.where(startgg_player_id: [
                set.slots.first.entrant.participants.first.player.id,
                set.slots.second.entrant.participants.first.player.id
              ])

              players.each do |player|
                opponent = (players - [player]).first
                next unless opponent.present?

                Setbot.notify_subscriptions(
                  event:,
                  player:,
                  opponent:,
                  stream_name: set.stream.stream_name,
                  startgg_set_id: set.id
                )
              end

              player = player.first
              opponent = (players - [player]).first
              next unless opponent.present?

              previous_notification = Notification.where(
                notifiable: player,
                notification_type: Notification::TYPE_PLAYER_SET_LIVE,
                platform: Notification::PLATFORM_DISCORD,
                success: true
              ).order(sent_at: :desc).first

              next if previous_notification.present? && previous_notification.metadata.with_indifferent_access[:startgg_set_id].to_s == set.id.to_s

              Notification.send_notification(
                player,
                type: Notification::TYPE_PLAYER_SET_LIVE,
                platform: Notification::PLATFORM_DISCORD,
                metadata: { startgg_set_id: set.id }
              ) do |player|
                Discord.player_set_live(
                  event:,
                  player:,
                  opponent:,
                  stream_name: set.stream.stream_name
                )
              end

            elsif set.state == Event::SET_STATE_COMPLETED
              next unless set.winner_id.present?
              next unless set.phase_group&.bracket_type == Event::BRACKET_TYPE_DOUBLE_ELIMINATION

              entrant_startgg_ids = set.slots.map(&:entrant).map(&:id)
              next unless entrant_startgg_ids.count == 2

              winner_entrant = event.entrants.find_by(startgg_entrant_id: set.winner_id)
              next unless winner_entrant.present? && winner_entrant.seed.present?

              loser_entrant = event.entrants.find_by(startgg_entrant_id: (entrant_startgg_ids - [set.winner_id]).first)
              next unless loser_entrant.present? && loser_entrant.seed.present?

              upset_factor = Event.upset_factor(
                winner_seed: winner_entrant.seed,
                loser_seed: loser_entrant.seed
              )

              # TODO: tweet
              Rails.logger.info("Set #{set.id} complete, #{winner_entrant.tag} (seed #{winner_entrant.seed}) beat #{loser_entrant.tag} (seed #{loser_entrant.seed}), upset factor: #{upset_factor}")
            end

          end

          break if sets.count < 50

          sleep 1
        end

        Rails.logger.info("Updating sets_synced_at to #{start_time}")
        event.sets_synced_at = start_time
        event.save!
      end
    end
  end

  private

  def updated_log(tournament, events)
    tournament_changes = tournament.saved_changes.reject { |k| k == 'updated_at' }
    Rails.logger.info "~ #{tournament.slug}: #{tournament_changes}"
    events.each do |event|
      event_changes = event.saved_changes.reject { |k| k == 'updated_at' }
      next if event_changes.blank?

      Rails.logger.info "  ~ #{event.game.slug.upcase}: #{event_changes}"
    end
  end

  def puts_dev(msg)
    Rails.logger.info(msg) if Rails.env.development?
  end
end
