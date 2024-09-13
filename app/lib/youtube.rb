class Youtube
  @client = nil

  class << self

    def channel_url(channel_name)
      Rails.cache.fetch("youtube_channel_url_#{channel_name}", expires_in: Rails.env.development? ? 5.seconds : 6.hours) do 
        puts "Fetching YouTube channel info for #{channel_name}..."
        response = client.list_searches('snippet', type: 'channel', q: channel_name)
        "https://youtube.com/channel/#{response.items.first.id.channel_id}"
      rescue => e
        puts e.message
        "https://youtube.com/#{channel_name}"
      end
    end

    def client
      return @client if @client.present?

      @client = Google::Apis::YoutubeV3::YouTubeService.new
      @client.key = Rails.application.credentials.dig(:youtube, :api_key)

      @client
    end

  end
end
