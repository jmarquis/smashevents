# == Schema Information
#
# Table name: event_sets
#
#  id                :bigint           not null, primary key
#  completed_at      :datetime
#  entrant1_score    :integer
#  entrant2_score    :integer
#  started_at        :datetime
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  discord_post_id   :string
#  entrant1_id       :bigint           not null
#  entrant2_id       :bigint           not null
#  event_id          :bigint           not null
#  provider_set_id   :string           not null
#  stream_id         :bigint
#  winner_entrant_id :bigint
#
# Indexes
#
#  index_event_sets_on_entrant1_id        (entrant1_id)
#  index_event_sets_on_entrant2_id        (entrant2_id)
#  index_event_sets_on_event_id           (event_id)
#  index_event_sets_on_provider_set_id    (provider_set_id)
#  index_event_sets_on_stream_id          (stream_id)
#  index_event_sets_on_winner_entrant_id  (winner_entrant_id)
#
class EventSet < ApplicationRecord
  PLACEMENTS = [1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025]

  belongs_to :event
  belongs_to :entrant1, class_name: 'Entrant'
  belongs_to :entrant2, class_name: 'Entrant'
  belongs_to :winner_entrant, class_name: 'Entrant', optional: true
  belongs_to :stream, optional: true

  def loser_entrant
    return nil if winner_entrant.blank?

    winner_entrant == entrant1 ? entrant2 : entrant1
  end

  def winner_score
    return nil if winner_entrant.blank?

    winner_entrant == entrant1 ? entrant1_score : entrant2_score
  end

  def loser_score
    return nil if winner_entrant.blank?

    winner_entrant == entrant1 ? entrant2_score : entrant1_score
  end

  def upset_factor
    winner_seed_placement_index = PLACEMENTS.count { |placement| winner_entrant.seed >= placement } - 1
    loser_seed_placement_index = PLACEMENTS.count { |placement| loser_entrant.seed >= placement } - 1
    winner_seed_placement_index - loser_seed_placement_index
  end
end
