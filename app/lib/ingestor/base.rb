module Ingestor
  class Base
    class << self
      def sync
        sync_tournaments
        sync_overrides
        sync_entrants
      end

      def sync_tournaments(before_date: nil, limit: nil, sync_entrants: false, delete_if_shouldnt_display: false)
        stats = {
          analyzed: 0,
          imported: 0,
          updated: 0
        }

        entrant_stats = {
          created: 0,
          updated: 0,
          deleted: 0
        }

        start_time = Time.now
        last_sync = Rails.cache.read("#{provider_name}/last_tournament_sync")
        last_full_sync = Rails.cache.read("#{provider_name}/last_full_tournament_sync")
        full_sync = last_full_sync.blank? || last_full_sync < 24.hours.ago

        cursor = nil
        winner_resync_data = nil

        Rails.logger.info "Starting #{provider_name} tournament sync (last sync: #{last_sync.inspect}, full sync: #{full_sync})..."

        (1..1000).each do |page|
          tournaments, cursor = if before_date.present?
            Rails.logger.info "Fetching page #{page} of past tournaments..."

            provider.tournaments(
              page:,
              cursor:,
              before_date:,
              sort_order: Provider::Base::SORT_ORDER_NEWEST_FIRST
            )
          else
            Rails.logger.info "Fetching page #{page} of upcoming tournaments..."

            provider.tournaments(
              page:,
              cursor:,
              after_date: 7.days.ago,
              updated_after: (!full_sync && last_sync.present? ? last_sync - 5.minutes : 1.year.ago),
              sort_order: Provider::Base::SORT_ORDER_OLDEST_FIRST
            )
          end

          break if tournaments.blank?

          Rails.logger.info "#{tournaments.count} tournaments found. Analyzing..."
          stats[:analyzed] += tournaments.count

          tournaments.each do |data|
            tournament, events = factory.tournament(data)

            next if events.blank?
            next if before_date.blank? && tournament.end_at < 7.days.ago
            next if tournament.exclude?
            next unless events.any?(&:should_ingest?) || tournament.should_ingest?

            if tournament.persisted?
              if tournament.changed? || events.any?(&:changed?)
                tournament.save!
                events.each(&:save!)

                tournament.events.each do |event|
                  Rails.cache.delete("tournament_has_other_events_for_game_#{event.id}")
                end

                StatsD.increment("#{provider_name}.tournament_updated")
                updated_log(tournament, events)
                stats[:updated] += 1
              end
            else
              tournament.save!
              events.each(&:save!)

              stats[:imported] += 1
              StatsD.increment("#{provider_name}.tournament_added")
              event_blurbs = events.map { |event| "#{event.game.slug}: #{event.entrant_count}" }
              Rails.logger.info "+ #{tournament.slug}: #{event_blurbs.join(', ')}"
            end

            if sync_entrants
              events.each do |event|
                next if event.entrants_synced_at.present? && event.entrants_synced_at > 1.hour.ago

                entrant_stats = event.sync_entrants!.each_with_object(entrant_stats) do |(key, total), entrant_stats|
                  entrant_stats[key] += total
                end
              end

              # Now that we have entrant data, sync the tournament again to
              # populate the winner entrant if necessary. Only redo once per
              # tournament so a persistently missing winner can't loop forever.
              if !winner_resync_data.equal?(data) && events.any? { |event| event.winner_entrant.blank? && event.completed? }
                winner_resync_data = data
                redo
              end

              if delete_if_shouldnt_display && !tournament.should_display?
                tournament.destroy!
              end
            end

            yield(tournament) if block_given?
          end

          break if limit.present? && stats[:analyzed] >= limit

          sleep provider.sleep_time
        end

        # Don't update this stuff if we're syncing past tournaments.
        unless before_date.present?
          Rails.cache.write("#{provider_name}/last_tournament_sync", start_time, expires_in: 1.day)
          Rails.cache.write("#{provider_name}/last_full_tournament_sync", start_time, expires_in: 1.day) if full_sync
        end

        Rails.logger.info "#{provider_name} tournament sync complete. #{stats.to_json}"
        Rails.logger.info "Entrants synced: #{entrant_stats.to_json}" if sync_entrants
      end

      def sync_overrides
        stats = {
          analyzed: 0,
          imported: 0,
          updated: 0,
          deleted: 0
        }

        Rails.logger.info "Starting #{provider_name} override sync..."

        TournamentOverride.where(provider: provider_name).each do |override|
          unless override.include
            tournament = Tournament.find_by(slug: override.slug, provider: provider_name)
            if tournament.present?
              Rails.logger.info "- #{tournament.slug}"

              StatsD.increment("#{provider_name}.tournament_deleted")
              tournament.destroy
              stats[:deleted] += 1
            end

            next
          end

          tournament = Tournament.find_by(slug: override.slug, provider: provider_name)
          next if tournament.present? && tournament.end_at < 7.days.ago

          stats[:analyzed] += 1

          Rails.logger.info "Fetching tournament #{override.slug}..."
          data = provider.tournament(slug: override.slug)

          tournament, events = factory.tournament(data)

          if tournament.persisted?
            if tournament.changed? || events.any?(&:changed?)
              tournament.save!
              events.each(&:save!)

              StatsD.increment("#{provider_name}.tournament_updated")
              updated_log(tournament, events)
              stats[:updated] += 1
            end
          else
            tournament.save!
            events.each(&:save!)

            StatsD.increment("#{provider_name}.tournament_added")
            event_blurbs = events.map { |event| "#{event.game.slug}: #{event.entrant_count}" }
            Rails.logger.info "+ #{tournament.slug}: #{event_blurbs.join(',')}"
            stats[:imported] += 1
          end

          # Update override slug to match actual tournament slug
          override.slug = tournament.slug
          override.save!

          sleep provider.sleep_time
        end

        Rails.logger.info "Tournament override sync complete. #{stats.to_json}"
      end

      def sync_entrants
        num_events = 0
        stats = {
          created: 0,
          updated: 0,
          deleted: 0
        }

        Rails.logger.info 'Starting entrant sync...'

        tournaments = Tournament.not_past.reasonable_duration.where(provider: provider_name)

        tournaments.each do |tournament|
          unseeded_in_progress_events = tournament.events.in_progress.where(is_seeded: false)
          events = tournament.events.should_sync_entrants

          [*unseeded_in_progress_events, *events].each do |event|
            stats = event.sync_entrants!.each_with_object(stats) do |(key, total), stats|
              stats[key] += total
            end

            num_events += 1
            Rails.logger.info "Scanned #{num_events} events so far..." if num_events % 50 == 0
          end
        end

        Rails.logger.info "Entrant sync complete. #{stats.to_json}"
      end

      def sync_sets
        events = []

        # We want to look at all in-progress tournaments with events above the
        # display threshold. We don't filter by event state here because there's
        # no guarantee that the state is in sync, so we'll sync all of them now.
        Tournament.where(provider: provider_name).should_display.in_progress.each do |tournament|
          events += tournament.events.filter(&:should_display?)
        end

        # We also want to look at events from in-progress tournaments with
        # streams that have a player with a Setbot subscription, so we can
        # notify for those even if the event doesn't meet the display threshold.
        events += Event.joins(entrants: { player: :player_subscriptions })
          .where(tournament_id: Tournament.in_progress.has_streams.select(:id))
          .distinct

        # In case the two resultsets above overlap...
        events.uniq!

        # Sync the state now because if the event just started or ended, this is
        # where we'll find out.
        #
        # TODO: Think of a way to be smarter about this so we don't have to do
        # it every single time we poll for sets.
        events.each do |event|
          event.sync_state!
          sleep provider.sleep_time
        end

        # We don't want the tournament to be touched when we sync sets because
        # that will cause unnecessary turbo stream updates.
        Tournament.no_touching do

          # Now we can filter by event state since we just synced it.
          events.filter(&:in_progress?).each(&:sync_sets!)
        end
      end

      private

      def provider_name
        self::PROVIDER_NAME
      end

      def provider
        Provider::Base.provider(self::PROVIDER_NAME)
      end

      def factory
        Factory::Base.factory(self::PROVIDER_NAME)
      end

      def updated_log(tournament, events)
        tournament_changes = tournament.saved_changes.reject { |k| k == 'updated_at' }
        Rails.logger.info "~ #{tournament.slug}: #{tournament_changes}"
        events.each do |event|
          event_changes = event.saved_changes.reject { |k| k == 'updated_at' }
          next if event_changes.blank?

          Rails.logger.info "  ~ #{event.game.slug.upcase}: #{event_changes}"
        end
      end

    end
  end
end
