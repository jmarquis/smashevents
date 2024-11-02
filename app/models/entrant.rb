# == Schema Information
#
# Table name: entrants
#
#  id                 :bigint           not null, primary key
#  rank               :integer
#  seed               :integer
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  event_id           :bigint           not null
#  player_id          :bigint           not null
#  startgg_entrant_id :integer
#
# Indexes
#
#  index_entrants_on_event_id            (event_id)
#  index_entrants_on_event_id_and_rank   (event_id,rank)
#  index_entrants_on_event_id_and_seed   (event_id,seed)
#  index_entrants_on_player_id           (player_id)
#  index_entrants_on_startgg_entrant_id  (startgg_entrant_id) UNIQUE
#
class Entrant < ApplicationRecord
  belongs_to :player
  belongs_to :event

  def self.from_startgg(event, data)
    e = find_by(startgg_entrant_id: data.id) || new

    e.event = event
    e.startgg_entrant_id = data.id
    e.seed = data.initial_seed_num

    rankings_key = Game.by_slug(event.game).rankings_key
    rankings_regex = Game.by_slug(event.game).rankings_regex
    e.rank = data.participants[0]&.player&.send(rankings_key)&.filter { |ranking| ranking.title&.match(rankings_regex) }&.first&.rank

    e.player = Player.from_startgg(data.participants[0].player)

    e
  end
end
