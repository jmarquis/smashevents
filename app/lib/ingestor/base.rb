module Ingestor
  class Base
    class << self
      def sync
        sync_tournaments
        sync_overrides
        sync_entrants
      end

      def sync_tournaments
        stats = {
          analyzed: 0,
          imported: 0,
          updated: 0
        }
        start_time = Time.now
        last_sync = Rails.cache.read("#{provider_name}/last_tournament_sync")
        last_full_sync = Rails.cache.read("#{provider_name}/last_full_tournament_sync")
        full_sync = last_full_sync.blank? || last_full_sync < 24.hours.ago

        cursor = nil

        Rails.logger.info "Starting #{provider_name} tournament sync (last sync: #{last_sync.inspect}, full sync: #{full_sync})..."

        (1..1000).each do |page|
          Rails.logger.info "Fetching page #{page} of tournaments..."
          tournaments, cursor = provider.tournaments(
            page:,
            cursor:,
            after_date: 7.days.ago,
            updated_after: (!full_sync && last_sync.present? ? last_sync - 5.minutes : 1.year.ago)
          )

          break if tournaments.count.zero?
          Rails.logger.info "#{tournaments.count} tournaments found. Analyzing..."
          stats[:analyzed] += tournaments.count

          tournaments.each do |data|
            tournament = factory.tournament(data)

            next if tournament.events.blank?
            next if tournament.end_at < 7.days.ago
            next if tournament.exclude?
            next unless tournament.events.any?(&:should_ingest?) || tournament.should_ingest?

            if tournament.persisted?
              if tournament.changed? || tournament.events.any?(&:changed?)
                tournament.save!
                tournament.events.each(&:save!)

                StatsD.increment("#{provider_name}.tournament_updated")
                updated_log(tournament)
                stats[:updated] += 1
              end
            else
              tournament.save!

              stats[:imported] += 1
              StatsD.increment("#{provider_name}.tournament_added")
              event_blurbs = tournament.events.map { |event| "#{event.game.slug}: #{event.player_count}" }
              Rails.logger.info "+ #{tournament.slug}: #{event_blurbs.join(', ')}"
            end
          end

          sleep 1
        end

        Rails.cache.write("#{provider_name}/last_tournament_sync", start_time, expires_in: 1.day)
        Rails.cache.write("#{provider_name}/last_full_tournament_sync", start_time, expires_in: 1.day) if full_sync

        Rails.logger.info "#{provider_name} tournament sync complete. #{stats.to_json}"
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
          if !override.include
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
          next if tournament.present? && tournament.past?

          stats[:analyzed] += 1

          Rails.logger.info "Fetching tournament #{override.slug}..."
          data = provider.tournament(slug: override.slug)

          tournament = factory.tournament(data)

          if tournament.persisted?
            if tournament.changed? || tournament.events.any?(&:changed?)
              tournament.save!
              tournament.events.each(&:save!)

              StatsD.increment("#{provider_name}.tournament_updated")
              updated_log(tournament)
              stats[:updated] += 1
            end
          else
            tournament.save!

            StatsD.increment("#{provider_name}.tournament_added")
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
            stats = event.sync_entrants!.reduce(stats) do |stats, (key, total)|
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

      def scan_sets
        Tournament.where(provider: provider_name).should_display.in_progress.each do |tournament|
          tournament.events.each do |event|
            event.sync_state!
          end

          tournament.events.in_progress.each do |event|
            event.sync_sets!
          end
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

      def updated_log(tournament)
        tournament_changes = tournament.saved_changes.reject { |k| k == 'updated_at' }
        Rails.logger.info "~ #{tournament.slug}: #{tournament_changes}"
        tournament.events.each do |event|
          event_changes = event.saved_changes.reject { |k| k == 'updated_at' }
          next if event_changes.blank?

          Rails.logger.info "  ~ #{event.game.slug.upcase}: #{event_changes}"
        end
      end

    end
  end
end
