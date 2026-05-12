# == Schema Information
#
# Table name: entrants
#
#  id                  :integer          not null, primary key
#  player_id           :integer          not null
#  event_id            :integer          not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  provider_entrant_id :string
#  seed                :integer
#  rank                :integer
#  player2_id          :integer
#  provider            :string
#
# Indexes
#
#  index_entrants_on_event_id                          (event_id)
#  index_entrants_on_event_id_and_rank                 (event_id,rank)
#  index_entrants_on_event_id_and_seed                 (event_id,seed)
#  index_entrants_on_player2_id                        (player2_id)
#  index_entrants_on_player_id                         (player_id)
#  index_entrants_on_provider_and_provider_entrant_id  (provider,provider_entrant_id) UNIQUE
#

class Entrant < ApplicationRecord
  belongs_to :player
  belongs_to :player2, class_name: 'Player', optional: true
  belongs_to :event

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
