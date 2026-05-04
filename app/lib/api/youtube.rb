class Youtube < Api
  @client = nil

  class << self

    def channel_url(channel_name)
      Rails.logger.info "Fetching YouTube channel info for #{channel_name}..."

      response = instrument('list_searches') do
        client.list_searches('snippet', type: 'channel', q: channel_name)
      end

      "https://youtube.com/channel/#{response.items.first.id.channel_id}/live"
    rescue => e
      Rails.logger.error e.message
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
