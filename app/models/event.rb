# == Schema Information
#
# Table name: events
#
#  id                  :bigint           not null, primary key
#  featured_players    :string           is an Array
#  game                :string           not null
#  notified_added_at   :datetime
#  player_count        :integer
#  ranked_player_count :integer
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  startgg_id          :integer          not null
#  tournament_id       :bigint           not null
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
    player_count.present? && player_count >= Game.by_slug(game).ingestion_threshold
  end

  def should_display?
    return false unless Game.by_slug(game)&.display_threshold.present?
    return false unless player_count.present?

    # If the event is stacked with ranked players, always display it. This
    # should catch invitationals and stuff.
    if ranked_player_count.present? && ranked_player_count > 0 && player_count.present? && player_count > 0
      return true if ranked_player_count / player_count > 0.3
      return true if ranked_player_count > 10
    end

    score = player_count + ((ranked_player_count || 0) * 10)
    score > Game.by_slug(game).display_threshold
  end

  # Meant to be used like: "Featuring #{event.players_sentence}"
  def players_sentence
    if featured_players.present?
      remaining_player_count = player_count - featured_players.count
      
      if remaining_player_count >= 10
        "#{[*featured_players, "#{(player_count - featured_players.count)} more!"].to_sentence}"
      else
        "#{[*featured_players, 'more!'].to_sentence}"
      end
    else
      "#{player_count} players!"
    end
  end
end
