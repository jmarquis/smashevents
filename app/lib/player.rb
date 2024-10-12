class Player
  attr_accessor :tag, :twitter_username

  def initialize(params)
    params.each do |key, value|
      self.instance_variable_set("@#{key}".to_sym, value)
    end
  end

  def serialize
    {
      tag:,
      twitter_username:
    }.to_json
  end

  def twitter_url
    "https://twitter.com/#{twitter_username}" if twitter_username.present?
  end

  class << self

    def from_json(serialized_player)
      new(JSON.parse(serialized_player).deep_symbolize_keys)
    rescue JSON::ParserError
      new(tag: serialized_player)
    end

    def from_startgg(startgg_player)
      new(
        tag: startgg_player.gamer_tag,
        twitter_username: startgg_player&.user&.authorizations&.first&.external_username
      )
    end

  end
end
