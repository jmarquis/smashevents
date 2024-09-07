class Twitter
  @client = nil

  class << self

    def notify_tournament_added(tournament)
      client.post('tweets', JSON.generate({
        text: <<~TEXT
          New tournament added to smashevents.gg!
          \n\n
          #{tournament.name.upcase}
          #{tournament.formatted_date_range}
          #{tournament.formatted_location}
          \n\n
          Featuring #{tournament.events.map { |event| Game.by_slug(event.game).name }.to_sentence}.
          \n\n
          ##{tournament.hashtag}
          \n\n
          https://start.gg/#{tournament.slug}
        TEXT
      }))
    end

    def client
      return @client if @client

      @client = X::Client.new(
        api_key: Rails.application.credentials.dig(:twitter, :api_key),
        api_key_secret: Rails.application.credentials.dig(:twitter, :api_key_secret),
        access_token: Rails.application.credentials.dig(:twitter, :access_token),
        access_token_secret: Rails.application.credentials.dig(:twitter, :access_token_secret)
      )
    end

  end
end
