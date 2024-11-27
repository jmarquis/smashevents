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
#  player2_id         :integer
#
# Indexes
#
#  index_entrants_on_event_id            (event_id)
#  index_entrants_on_event_id_and_rank   (event_id,rank)
#  index_entrants_on_event_id_and_seed   (event_id,seed)
#  index_entrants_on_player2_id          (player2_id)
#  index_entrants_on_player_id           (player_id)
#  index_entrants_on_startgg_entrant_id  (startgg_entrant_id) UNIQUE
#

class Entrant < ApplicationRecord
  belongs_to :player
  belongs_to :player2, class_name: 'Player', optional: true
  belongs_to :event

  def self.from_startgg_entrant(data, event:)
    e = find_by(startgg_entrant_id: data.id) || new

    e.event = event
    e.startgg_entrant_id = data.id
    e.seed = data.initial_seed_num

    rankings_key = event.game.rankings_key
    rankings_regex = event.game.rankings_regex
    e.rank = data.participants[0]&.player&.send(rankings_key)&.filter { |ranking| ranking.title&.match(rankings_regex) }&.first&.rank

    e.player = Player.from_startgg_player(data.participants[0].player)

    if data.participants.count > 1
      player2_rank = data.participants[1]&.player&.send(rankings_key)&.filter { |ranking| ranking.title&.match(rankings_regex) }&.first&.rank
      e.rank = player2_rank if player2_rank.present? && (e.rank.blank? || player2_rank < e.rank)

      e.player2 = Player.from_startgg_player(data.participants[1].player)
    end

    e
  end

  def tag(twitter: false)
    player1_tag = if twitter && player.twitter_username.present?
      "#{player.tag} (@#{player.twitter_username})"
    else
      player.tag
    end

    return player1_tag unless player2.present?

    player2_tag = if twitter && player2.twitter_username.present?
      "#{player2.tag} (@#{player2.twitter_username})"
    else
      player2.tag
    end

    "#{player1_tag} / #{player2_tag}"
  end
end
