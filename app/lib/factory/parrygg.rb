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

        t.stream_data = nil # TODO: Figure out a way to get this

        events = []

        Game.all.each do |game|
          biggest_event = (data[:events] || [])
            .filter { |event| event[:game][:id] == game.parrygg_id }
            # TODO: It seems like most events on Parrygg have an empty start date?
            # .filter { |event| DateTime.parse(event[:startDate]) >= t.start_at - 2.days }
            .max { |a, b| a[:entrantCount] || 0 <=> b[:entrantCount] || 0 }

          next unless biggest_event.present?

          event = t.events.find_by(game:) || t.events.new

          event.provider_event_id = biggest_event[:id]
          event.slug = [t.slug, biggest_event[:slug]].join('/')
          event.state = biggest_event[:state]
          event.start_at = DateTime.parse(biggest_event[:startDate])
          event.game = game
          event.player_count = biggest_event[:entrantCount]

          # TODO: Figure out a way to get winner data

          events << event
        end

        [t, events]
      end

    end
  end
end
