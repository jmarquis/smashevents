# == Schema Information
#
# Table name: events
#
#  id                  :integer          not null, primary key
#  tournament_id       :integer          not null
#  startgg_id          :integer          not null
#  game_slug           :string           not null
#  player_count        :integer
#  featured_players    :string           is an Array
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  ranked_player_count :integer
#  notified_added_at   :datetime
#  start_at            :datetime
#  is_seeded           :boolean
#  synced_at           :datetime
#  slug                :string
#
# Indexes
#
#  index_events_on_startgg_id                   (startgg_id) UNIQUE
#  index_events_on_tournament_id                (tournament_id)
#  index_events_on_tournament_id_and_game_slug  (tournament_id,game_slug) UNIQUE
#

class Event < ApplicationRecord
  belongs_to :tournament
  has_many :entrants
  has_many :players, through: :entrants
  belongs_to :game, foreign_key: :game_slug, primary_key: :slug

  scope :should_sync, -> { where("coalesce(synced_at, now() - interval '1 day') - coalesce(player_count, 0) * interval '100 seconds' <= ?", 1.day.ago) }

  def should_ingest?
    return false unless game&.ingestion_threshold.present?
    player_count.present? && player_count >= game.ingestion_threshold
  end

  def should_display?
    return false unless game&.display_threshold.present?
    return true if tournament.override.present? && tournament.override.include
    return false unless player_count.present?

    # If the event is stacked with ranked players, always display it. This
    # should catch invitationals and stuff.
    if ranked_player_count.present? && ranked_player_count > 0 && player_count.present? && player_count > 0
      return true if ranked_player_count.to_f / player_count.to_f > 0.3
      return true if ranked_player_count > 10
    end

    score = player_count + ((ranked_player_count || 0) * 10)
    score > game.display_threshold
  end

  # Meant to be used like: "Featuring #{event.players_sentence}"
  def players_sentence(twitter: false, show_count: true)
    if featured_players.present?
      remaining_player_count = player_count - featured_players.count

      players = featured_players.map do |player|
        if twitter && player.twitter_username.present?
          "#{player.tag} (@#{player.twitter_username})"
        else
          player.tag
        end
      end

      if show_count && remaining_player_count >= 10
        "#{[*players, "#{(player_count - featured_players.count)} more!"].to_sentence}"
      else
        "#{[*players, 'more!'].to_sentence}"
      end
    elsif show_count
      "#{player_count} players!"
    end
  end

  def entrants_sentence(twitter: false, show_count: true)
    entrants = featured_entrants
    if entrants.present?
      remaining_entrant_count = player_count - entrants.count

      entrants_tags = entrants.map { |entrant| entrant.tag(twitter:) }

      if show_count && remaining_entrant_count >= 10
        "#{[*entrants_tags, "#{(player_count - entrants.count)} more!"].to_sentence}"
      else
        "#{[*entrants_tags, 'more!'].to_sentence}"
      end
    elsif show_count
      "#{player_count} players!"
    end
  end

  def featured_entrants
    Rails.cache.fetch("featured_entrants_#{id}", expires_in: Rails.env.development? ? 5.seconds : 1.hour) do
      if is_seeded
        entrants.includes(:player, :player2).where('seed is not null').order(seed: :asc).limit(10)
      elsif ranked_player_count.present? && ranked_player_count > 0
        entrants.includes(:player, :player2).where('rank is not null').order(rank: :asc).limit(10)
      end
    end
  end

  def featured_players
    Rails.cache.fetch("featured_players_#{id}", expires_in: Rails.env.development? ? 5.seconds : 1.hour) do
      if is_seeded
        entrants.includes(:player).where('seed is not null').order(seed: :asc).limit(10).map(&:player)
      elsif ranked_player_count.present? && ranked_player_count > 0
        entrants.includes(:player).where('rank is not null').order(rank: :asc).limit(10).map(&:player)
      end
    end
  end

  def startgg_url
    "https://start.gg/#{slug}"
  end
end
