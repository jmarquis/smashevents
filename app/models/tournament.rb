# == Schema Information
#
# Table name: tournaments
#
#  id               :bigint           not null, primary key
#  city             :string
#  country          :string
#  end_at           :date
#  featured_players :string
#  games            :string           is an Array
#  name             :string
#  player_count     :integer
#  slug             :string
#  start_at         :date
#  state            :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  startgg_id       :integer
#
# Indexes
#
#  index_tournaments_on_games       (games) USING gin
#  index_tournaments_on_name        (name)
#  index_tournaments_on_start_at    (start_at)
#  index_tournaments_on_startgg_id  (startgg_id) UNIQUE
#
class Tournament < ApplicationRecord

  MELEE = 'melee'
  ULTIMATE = 'ultimate'

  MELEE_ID = 1
  ULTIMATE_ID = 1386

  ID_TO_GAME = {
    MELEE_ID => MELEE,
    ULTIMATE_ID => ULTIMATE
  }

  def self.from_startgg(data)
    games = data.events&.reduce([]) do |games, event|
      next if event.videogame.blank?
      next if event.videogame.id.blank?
      next if ID_TO_GAME[event.videogame.id].blank?
      next if ID_TO_GAME[event.videogame.id].in? games

      games << ID_TO_GAME[event.videogame.id]
    end

    t = find_by(startgg_id: data.id) || new

    t.slug = data.slug
    t.name = data.name
    t.start_at = data.start_at.present? ? Time.at(data.start_at).to_date : nil
    t.end_at = data.end_at.present? ? Time.at(data.end_at).to_date : nil
    t.player_count = data.num_attendees || 0
    t.city = data.city
    t.state = data.addr_state
    t.country = data.country_code
    t.games = games

    t
  end

  def interesting?
    player_count.present? && player_count > 100
  end



end
