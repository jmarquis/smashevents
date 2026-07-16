module Factory
  class Parrygg < Base
    class << self

      def tournament(data)
        t = Tournament.find_by(provider: Provider::Parrygg::PROVIDER_NAME, provider_tournament_id: data[:id]) || Tournament.new

        t.provider = Provider::Parrygg::PROVIDER_NAME
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
          t.banner_image_url = data[:images].filter { |image| image[:type] == 'IMAGE_TYPE_BANNER' }.first
          t.profile_image_url = data[:images].filter { |image| image[:type] == 'IMAGE_TYPE_AVATAR' }.first
        end

        # TODO: Feels pretty bad making API calls in a factory method...
        stream_data = Api::Parrygg.tournament_streams(tournament_id: data[:id])

        t.stream_data = if stream_data.present? && stream_data[:streams].present?
          stream_data[:streams]&.map do |stream|
            stream_data = (t.stream_data || []).map(&:deep_symbolize_keys).find { |data| data[:name]&.downcase == stream[:channel].downcase } || {}

            stream_data[:name] = stream[:channel]
            stream_data[:source] = case stream[:platform]
            when 'STREAM_PLATFORM_TWITCH'
              Tournament::STREAM_SOURCE_TWITCH
            when 'STREAM_PLATFORM_YOUTUBE'
              Tournament::STREAM_SOURCE_YOUTUBE
            end

            stream_data
          end
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

          # Some TOs make a single tournament for a weekly for some reason, and
          # just move the tournament's start_at and end_at every week. So make
          # sure we don't consider old events part of the current tournament.
          # NB: Give a couple days of grace because some TOs also mess this up
          # for legitimate tournaments.
          next unless parrygg_event[:startDate].blank? || Time.at(parrygg_event[:startDate]) >= t.start_at - 2.days

          event = t.events.find_by(game:) || t.events.new

          event.provider_event_id = biggest_event[:id]
          event.slug = [t.slug, biggest_event[:slug]].join('/')
          event.state = biggest_event[:state]
          event.start_at = DateTime.parse(biggest_event[:startDate])
          event.game = game
          event.entrant_count = biggest_event[:entrantCount]

          # TODO: Figure out a way to get winner data

          events << event
        end

        [t, events]
      end

      def entrant(data, event:)
        e = Entrant.find_by(provider: Provider::Parrygg::PROVIDER_NAME, provider_entrant_id: data[:id]) || Entrant.new

        e.event = event
        e.provider = Provider::Parrygg::PROVIDER_NAME
        e.provider_entrant_id = data[:id]
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
        return Player.new(provider: Provider::Parrygg::PROVIDER_NAME, tag:) if data.blank?

        p = Player.find_by(provider: Provider::Parrygg::PROVIDER_NAME, provider_player_id: data[:id]) || Player.new

        p.provider = Provider::Parrygg::PROVIDER_NAME
        p.provider_player_id = data[:id]
        p.provider_user_id = data[:id]
        p.provider_user_slug = nil
        p.tag = data[:gamerTag]
        p.twitter_username = nil
        p.name = [data[:firstName], data[:lastName]].join(' ')

        p
      end

    end
  end
end
