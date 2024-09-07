class Discord
  @client = nil

  class << self

    def notify_tournament_added(tournament)
      client.execute do |builder|
        builder.content = 'New tournament added!'
        builder.add_embed do |embed|
          embed.title = tournament.name
          embed.description = [
            tournament.formatted_date_range,
            [
              tournament.city,
              tournament.state,
              tournament.country.in?(['US', 'GB']) ? nil : tournament.country
            ].compact.join(', '),
            '',
            *tournament.events.map { |event|
              "#{Game.by_slug(event.game).name}: #{event.player_count || 0} players"
            }
          ].join("\n")
          embed.timestamp = tournament.start_at
        end
      end
    end

    def client
      return @client if @client

      @client = Discordrb::Webhooks::Client.new(url: Rails.application.credentials.dig(:discord, :webhook_url))
    end

  end
end
