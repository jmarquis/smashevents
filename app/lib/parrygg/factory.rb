module Parrygg
  class Factory < ::Factory
    EVENT_STATE_UNSPECIFIED = 'EVENT_STATE_UNSPECIFIED'
    EVENT_STATE_PENDING = 'EVENT_STATE_PENDING'
    EVENT_STATE_READY = 'EVENT_STATE_READY'
    EVENT_STATE_IN_PROGRESS = 'EVENT_STATE_IN_PROGRESS'
    EVENT_STATE_COMPLETED = 'EVENT_STATE_COMPLETED'

    LINKED_ACCOUNT_PROVIDER_STARTGG = 'LINKED_ACCOUNT_PROVIDER_STARTGG'

    class << self

      def tournament(data)
        t = Tournament.find_by(provider: Provider::PROVIDER_NAME, provider_tournament_id: data[:id]) || Tournament.new

        t.provider = Provider::PROVIDER_NAME
        t.provider_tournament_id = data[:id]
        t.slug = data[:slugs].first[:slug]
        t.name = data[:name]
        t.hashtag = nil # parrygg doesn't have this
        t.start_at = data[:startDate].present? ? DateTime.parse(data[:startDate]) : nil
        t.end_at = data[:endDate].present? ? DateTime.parse(data[:endDate]) : nil
        t.timezone = data[:timeZone]
        t.city = data.dig(:address, :locality)
        t.state = data.dig(:address, :administrativeAreaLevel1)
        t.country = data.dig(:address, :countryCode)

        if data[:images].present?
          t.banner_image_url = data[:images].find { |image| image[:type] == 'IMAGE_TYPE_BANNER' }&.dig(:url)
          t.profile_image_url = data[:images].find { |image| image[:type] == 'IMAGE_TYPE_AVATAR' }&.dig(:url)
        end

        events = []

        return t, events unless data[:events].present?

        data[:events].each do |parrygg_event|
          game = Game.find_by(parrygg_id: parrygg_event[:game][:id])
          next unless game.present?

          unless t.override&.include
            next unless parrygg_event[:entrantCount].present?
            next unless parrygg_event[:entrantCount] >= game.ingestion_threshold
          end

          event = t.events.find_by(provider_event_id: parrygg_event[:id]) || t.events.new

          event.provider_event_id = parrygg_event[:id]
          event.slug = [t.slug, parrygg_event[:slug]].join('/')
          event.state = event_state(parrygg_event[:state])
          event.game = game
          event.entrant_count = parrygg_event[:entrantCount]

          event_start = if parrygg_event[:startDate].present?
            DateTime.parse(parrygg_event[:startDate])
          end

          # Parrygg seems to default empty dates to the Unix epoch, so treat
          # those as nil in our data.
          event.start_at = event_start.present? && event_start != Time.at(0) ? event_start : t.start_at

          # Some TOs make a single tournament for a weekly for some reason, and
          # just move the tournament's start_at and end_at every week. So make
          # sure we don't consider old events part of the current tournament.
          #
          # NB: Give a couple days of grace because some TOs also mess this up
          # for legitimate tournaments.
          #
          # NB: An empty start date is okay here because a lot of Parrygg events
          # don't seem to have a start date for some reason.
          next unless event.start_at.blank? || event.start_at >= t.start_at - 2.days

          # TODO: Probably should move this API call out of the factory, but
          # this should be so infrequent that it's okay for now.
          if event.state == Event::STATE_COMPLETED
            event.winner_entrant = event.entrants.find_by(
              provider_entrant_id: Provider.event_winner_entrant_id(provider_event_id: event.provider_event_id)
            )
          end

          events << event
        end

        [t, events]
      end

      def entrant(data, event:)
        e = event.entrants.find_by(provider: Provider::PROVIDER_NAME, provider_entrant_id: data.dig(:entrant, :id)) || event.entrants.new

        e.provider = Provider::PROVIDER_NAME
        e.provider_entrant_id = data.dig(:entrant, :id)
        e.seed = data[:seed]

        # TODO: As of July 2026, the Parrygg API has no ranking data. If/when
        # they add it, we should ingest it here.

        users = data.dig(:entrant, :users)

        e.player = player(users&.first, tag: data[:name])

        if users.present? && users.count > 1
          e.player2 = if users.second[:id] == users.first[:id]
            e.player
          else
            player(users.second)
          end
        end

        e
      end

      def player(data, tag: nil)
        return Player.new(provider: Provider::PROVIDER_NAME, tag:) if data.blank?

        p = Player.find_by(provider: Provider::PROVIDER_NAME, provider_player_id: data[:id]) || Player.new

        p.provider = Provider::PROVIDER_NAME
        p.provider_player_id = data[:id]
        p.provider_user_id = data[:id]
        p.provider_user_slug = nil
        p.tag = data[:gamerTag]
        p.name = if data[:firstName].present? || data[:lastName].present?
          [data[:firstName], data[:lastName]].compact_blank.join(' ')
        end

        startgg_user_id = data[:linkedAccounts]&.find { |account| account[:provider] == LINKED_ACCOUNT_PROVIDER_STARTGG }&.dig(:userId)
        startgg_user = Player.find_by(provider: Startgg::Provider::PROVIDER_NAME, provider_user_id: startgg_user_id.to_s) if startgg_user_id.present?
        p.twitter_username ||= startgg_user&.twitter_username

        p
      end

      def event_state(parrygg_state)
        case parrygg_state
        when EVENT_STATE_UNSPECIFIED
          nil
        when EVENT_STATE_PENDING
          Event::STATE_CREATED
        when EVENT_STATE_READY
          Event::STATE_READY
        when EVENT_STATE_IN_PROGRESS
          Event::STATE_ACTIVE
        when EVENT_STATE_COMPLETED
          Event::STATE_COMPLETED
        end
      end

      def set(data, event:)
        set = event.event_sets.find_by(provider_set_id: data.dig(:match, :id)) || EventSet.new(event:)

        set.provider_set_id = data.dig(:match, :id)
        set.started_at = data.dig(:match, :startedAt)
        set.completed_at = data.dig(:match, :endedAt)

        set.entrant1 = if data[:seeds]&.first&.dig(:eventEntrant, :entrant, :id).present?
          event.entrants.find_by(provider_entrant_id: data[:seeds].first.dig(:eventEntrant, :entrant, :id))
        end

        set.entrant2 = if data[:seeds]&.second&.dig(:eventEntrant, :entrant, :id).present?
          event.entrants.find_by(provider_entrant_id: data[:seeds].second.dig(:eventEntrant, :entrant, :id))
        end

        set.entrant1_score = data.dig(:match, :slots)&.first&.score
        set.entrant2_score = data.dig(:match, :slots)&.second&.score

        # TODO: set.winner_entrant = ???

        set.stream = if data.dig(:match, :stream_queue_entry).present?
          event.tournament.streams.find_by(provider_stream_id: data.dig(:match, :stream_queue_entry, :stream_id))
        end
      end

    end
  end
end
