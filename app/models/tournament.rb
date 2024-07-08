# == Schema Information
#
# Table name: tournaments
#
#  id                        :bigint           not null, primary key
#  city                      :string
#  country                   :string
#  end_at                    :date
#  melee_featured_players    :string           is an Array
#  melee_player_count        :integer
#  name                      :string
#  slug                      :string
#  start_at                  :date
#  state                     :string
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

  MELEE_ID = 1
  ULTIMATE_ID = 1386

  MELEE_THRESHOLD = 100
  ULTIMATE_THRESHOLD = 300

  has_many :events, dependent: :destroy

  scope :upcoming, -> { where('end_at >= ?', Date.today) }

  def self.from_startgg(data)
    t = find_by(startgg_id: data.id) || new

    t.startgg_id = data.id
    t.slug = data.slug.match(/^tournament\/(.*)/)[1]
    t.name = data.name
    t.start_at = data.start_at.present? ? Time.at(data.start_at).in_time_zone(data.timezone).to_date : nil
    t.end_at = data.end_at.present? ? Time.at(data.end_at).in_time_zone(data.timezone).to_date : nil
    t.city = data.city
    t.state = data.addr_state
    t.country = data.country_code

    any_events_changed = false
    Game::GAMES.each do |game|
      biggest_event = data.events
        .filter { |event| event.videogame.id.to_i == game.startgg_id }
        .max { |a, b| a.num_entrants <=> b.num_entrants }

      if biggest_event.present?
        e = t.events.find_by(startgg_id: biggest_event.id) || t.events.new

        e.startgg_id = biggest_event.id
        e.game = game.slug
        e.player_count = biggest_event.num_entrants

        any_events_changed = any_events_changed || e.changed?
      end
    end

    return t, any_events_changed
  end

  def interesting?
    override = TournamentOverride.find_by(slug:)
    return override.include unless override&.include.nil?

    events.any?(&:interesting?)
  end

  def interesting_melee?
    melee_player_count.present? && melee_player_count > MELEE_THRESHOLD
  end

  def interesting_ultimate?
    ultimate_player_count.present? && ultimate_player_count > ULTIMATE_THRESHOLD
  end

end
