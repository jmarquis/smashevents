class Youtube
  @client = nil

  class << self

    def channel_url(channel_name)
      puts "Fetching YouTube channel info for #{channel_name}..."

      response = StatsD.measure('youtube.list_searches') do
        client.list_searches('snippet', type: 'channel', q: channel_name)
      end

      "https://youtube.com/channel/#{response.items.first.id.channel_id}/live"
    rescue => e
      puts e.message
      "https://youtube.com/#{channel_name}"
    end

    def client
      return @client if @client.present?

      @client = Google::Apis::YoutubeV3::YouTubeService.new
      @client.key = Rails.application.credentials.dig(:youtube, :api_key)

      @client
    end

  end
end
