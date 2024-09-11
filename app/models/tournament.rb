# == Schema Information
#
# Table name: tournaments
#
#  id                        :bigint           not null, primary key
#  city                      :string
#  country                   :string
#  end_at                    :datetime
#  hashtag                   :string
#  melee_featured_players    :string           is an Array
#  melee_player_count        :integer
#  name                      :string
#  slug                      :string
#  start_at                  :datetime
#  state                     :string
#  stream_data               :json
#  timezone                  :string
#  ultimate_featured_players :string           is an Array
#  ultimate_player_count     :integer
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  startgg_id                :integer
#
# Indexes
#
#  index_tournaments_on_name        (name)
#  index_tournaments_on_start_at    (start_at)
#  index_tournaments_on_startgg_id  (startgg_id) UNIQUE
#
class Tournament < ApplicationRecord
  include Memery

  STREAM_SOURCE_TWITCH = 'twitch'
  STREAM_SOURCE_YOUTUBE = 'youtube'

  STREAM_STATUS_LIVE = 'live'

  has_many :events, dependent: :destroy

  scope :upcoming, -> { where('end_at >= ?', Date.today) }

  def self.from_startgg(data)
    t = find_by(startgg_id: data.id) || new

    t.startgg_id = data.id
    t.slug = data.slug.match(/^tournament\/(.*)/)[1]
    t.name = data.name
    t.hashtag = data.hashtag
    t.start_at = data.start_at.present? ? Time.at(data.start_at) : nil
    t.end_at = data.end_at.present? ? Time.at(data.end_at) : nil
    t.timezone = data.timezone
    t.city = data.city
    t.state = data.addr_state
    t.country = data.country_code

    t.stream_data = data.streams&.map do |stream|
      stream_data = (t.stream_data || []).map(&:deep_symbolize_keys).find { |data| data[:name]&.downcase == stream.stream_name.downcase } || {}

      stream_data[:name] = stream.stream_name
      stream_data[:source] = stream.stream_source

      stream_data
    end

    events = []
    Game::GAMES.each do |game|
      biggest_event = data.events
        .filter { |event| event.videogame.id.to_i == game.startgg_id }
        .max { |a, b| a.num_entrants <=> b.num_entrants }

      if biggest_event.present?
        e = t.events.find_by(game: game.slug) || t.events.new

        e.startgg_id = biggest_event.id
        e.game = game.slug
        e.player_count = biggest_event.num_entrants

        events << e
      end
    end

    return t, events
  end

  def should_ingest?
    override = TournamentOverride.find_by(slug:)
    return override.include unless override&.include.nil?

    Game::GAMES.each do |game|
      event = events.find_by(game: game.slug)
      return true if event.present? && event.interesting?
    end

    false
  end

  def should_display?(games: Game::GAMES.map(&:slug))
    return false if events.find_by(game: games).blank?

    override = TournamentOverride.find_by(slug:)
    return override.include unless override&.include.blank?

    games.each do |game|
      event = events.find_by(game: game)
      return true if event.present? && event.interesting?
    end

    false
  end

  def exclude?
    override = TournamentOverride.find_by(slug:)
    override&.include == false
  end

  memoize def adjusted_start_at
    start_at.in_time_zone(timezone || 'America/New_York')
  end

  memoize def adjusted_end_at
    # Subtract a second because a lot of people set their tournaments to stop
    # at midnight, which is technically the next day.
    end_at.in_time_zone(timezone || 'America/New_York') - 1.second
  end

  def formatted_date_range
    if adjusted_start_at.day == adjusted_end_at.day
      adjusted_start_at.strftime('%b %-d, %Y')
    elsif adjusted_start_at.month == adjusted_end_at.month
      "#{adjusted_start_at.strftime('%b %-d')} – #{adjusted_end_at.strftime('%-d, %Y')}"
    elsif adjusted_start_at.year == adjusted_end_at.year
      "#{adjusted_start_at.strftime('%b %-d')} – #{adjusted_end_at.strftime('%b %-d, %Y')}"
    else
      "#{adjusted_start_at.strftime('%b %-d, %Y')} – #{adjusted_end_at.strftime('%b %-d, %Y')}"
    end
  end

  # Fri - Sun  or  Saturday
  def formatted_day_range
    if adjusted_start_at.day == adjusted_end_at.day
      adjusted_start_at.strftime('%A')
    else
      "#{adjusted_start_at.strftime('%a')} – #{adjusted_end_at.strftime('%a')}"
    end
  end

  def formatted_location
    return 'Online' if city.blank? && state.blank? && country.blank?
    [city, state, country.in?(['US', 'GB']) ? nil : country].compact.join(', ')
  end

end
