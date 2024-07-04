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

  scope :upcoming, -> { where('end_at >= ?', Date.today) }

  def self.from_startgg(data)
    t = find_by(startgg_id: data.id) || new

    t.startgg_id = data.id
    t.slug = data.slug.match(/^tournament\/(.*)/)[1]
    t.name = data.name
    t.start_at = data.start_at.present? ? Time.at(data.start_at).in_time_zone(data.timezone).to_date : nil
    t.end_at = data.end_at.present? ? Time.at(data.end_at).in_time_zone(data.timezone).to_date : nil
    t.melee_player_count = data.events.filter { |event| event.videogame.id.to_i == MELEE_ID }.reduce(0) do |max_player_count, event|
      [max_player_count, event.num_entrants || 0].max
    end
    t.ultimate_player_count = data.events.filter { |event| event.videogame.id.to_i == ULTIMATE_ID }.reduce(0) do |max_player_count, event|
      [max_player_count, event.num_entrants || 0].max
    end
    t.city = data.city
    t.state = data.addr_state
    t.country = data.country_code

    t
  end

  def interesting?
    override = TournamentOverride.find_by(slug:)
    return override.include unless override&.include.nil?

    interesting_melee? || interesting_ultimate?
  end

  def interesting_melee?
    melee_player_count.present? && melee_player_count > MELEE_THRESHOLD
  end

  def interesting_ultimate?
    ultimate_player_count.present? && ultimate_player_count > ULTIMATE_THRESHOLD
  end

end
