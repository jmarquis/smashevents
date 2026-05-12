module Factory
  class Startgg < Base
    class << self

      def tournament(data)
        t = Tournament.find_by(provider: Provider::Startgg::PROVIDER_NAME, provider_tournament_id: data.id) || Tournament.new

        t.provider = Provider::Startgg::PROVIDER_NAME
        t.provider_tournament_id = data.id
        t.slug = data.slug.match(/^tournament\/(.*)/)[1]
        t.name = data.name
        t.hashtag = data.hashtag
        t.start_at = data.start_at.present? ? Time.at(data.start_at) : nil
        t.end_at = data.end_at.present? ? Time.at(data.end_at) : nil
        t.timezone = data.timezone
        t.city = data.city
        t.state = data.addr_state
        t.country = data.country_code

        t.banner_image_url = data.images.blank? ? nil : data.images
          .filter { |image| image.type == 'banner' }
          .map { |image| image.url.gsub(/\?.*/, '') }
          .first

        t.profile_image_url = data.images.blank? ? nil : data.images
          .filter { |image| image.type == 'profile' }
          .map { |image| image.url.gsub(/\?.*/, '') }
          .first

        t.stream_data = data.streams&.map do |stream|
          stream_data = (t.stream_data || []).map(&:deep_symbolize_keys).find { |data| data[:name]&.downcase == stream.stream_name.downcase } || {}

          stream_data[:name] = stream.stream_name
          stream_data[:source] = stream.stream_source

          stream_data
        end

        events = []

        Game.all.each do |game|
          biggest_event = (data.events || [])
            .filter { |event| event.videogame.id.to_i == game.startgg_id }
            # Some TOs make a single tournament for a weekly for some reason, and
            # just move the tournament's start_at and end_at every week. So make
            # sure we don't consider old events part of the current tournament.
            # NB: Give a couple days of grace because some TOs also mess this up
            # for legitimate tournaments.
            .filter { |event| Time.at(event.start_at) >= t.start_at - 2.days }
            .max { |a, b| a.num_entrants <=> b.num_entrants }

          if biggest_event.present?
            # Look up by game because we only care about one event per game per
            # tournament.
            event = t.events.find_by(game:) || t.events.new

            event.provider_event_id = biggest_event.id
            event.slug = biggest_event.slug
            event.state = biggest_event.state
            event.start_at = Time.at(biggest_event.start_at)
            event.game = game
            event.player_count = biggest_event.num_entrants

            winner_data = biggest_event.standings&.nodes&.first&.entrant
            if event.state == Event::STATE_COMPLETED && winner_data.present?
              winner_entrant = event.entrants&.find_by(provider_entrant_id: winner_data.id)
              event.winner_entrant = winner_entrant if winner_entrant.present?
            else
              event.winner_entrant = nil
            end

            events << event
          end
        end

        return t, events
      end

    end
  end
end
