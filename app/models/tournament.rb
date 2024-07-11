# == Schema Information
#
# Table name: tournaments
#
#  id                        :bigint           not null, primary key
#  city                      :string
#  country                   :string
#  end_at                    :datetime
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

  has_many :events, dependent: :destroy

  scope :upcoming, -> { where('end_at >= ?', Date.today) }

  def self.from_startgg(data)
    t = find_by(startgg_id: data.id) || new

    t.startgg_id = data.id
    t.slug = data.slug.match(/^tournament\/(.*)/)[1]
    t.name = data.name
    t.start_at = data.start_at.present? ? Time.at(data.start_at) : nil
    t.end_at = data.end_at.present? ? Time.at(data.end_at - 1) : nil
    t.timezone = data.timezone
    t.city = data.city
    t.state = data.addr_state
    t.country = data.country_code

    t.stream_data = data.streams&.map do |stream|
      {
        name: stream.stream_name,
        source: stream.stream_source,
        status: stream.stream_status
      }
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

  def interesting?(games: Game::GAMES.map(&:slug))
    override = TournamentOverride.find_by(slug:)
    return override.include unless override&.include.nil?

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

end
