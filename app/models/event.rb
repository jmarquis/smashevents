# == Schema Information
#
# Table name: events
#
#  id               :bigint           not null, primary key
#  featured_players :string           is an Array
#  game             :string           not null
#  player_count     :integer
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  startgg_id       :integer          not null
#  tournament_id    :bigint           not null
#
# Indexes
#
#  index_events_on_startgg_id              (startgg_id) UNIQUE
#  index_events_on_tournament_id           (tournament_id)
#  index_events_on_tournament_id_and_game  (tournament_id,game) UNIQUE
#
class Event < ApplicationRecord
  belongs_to :tournament

  def should_ingest?
    return false unless Game.by_slug(game)&.ingestion_threshold.present?
    player_count.present? && player_count > Game.by_slug(game).ingestion_threshold
  end

  def should_display?
    return false unless Game.by_slug(game)&.display_threshold.present?
    player_count.present? && player_count > Game.by_slug(game).display_threshold
  end
end
