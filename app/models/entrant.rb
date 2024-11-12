# == Schema Information
#
# Table name: entrants
#
#  id                 :integer          not null, primary key
#  player_id          :integer          not null
#  event_id           :integer          not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  startgg_entrant_id :integer
#  seed               :integer
#  rank               :integer
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

    rankings_key = event.game.rankings_key
    rankings_regex = event.game.rankings_regex
    e.rank = data.participants[0]&.player&.send(rankings_key)&.filter { |ranking| ranking.title&.match(rankings_regex) }&.first&.rank

    e.player = Player.from_startgg(data.participants[0].player)

    e
  end
end
