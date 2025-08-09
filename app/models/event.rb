# == Schema Information
#
# Table name: events
#
#  id                  :integer          not null, primary key
#  tournament_id       :integer          not null
#  startgg_id          :integer          not null
#  game_slug           :string           not null
#  player_count        :integer
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  ranked_player_count :integer
#  start_at            :datetime
#  is_seeded           :boolean
#  entrants_synced_at  :datetime
#  slug                :string
#  winner_entrant_id   :integer
#  state               :string
#  sets_synced_at      :datetime
#  should_display      :boolean
#  last_upset_tweet_id :string
#
# Indexes
#
#  index_events_on_startgg_id                   (startgg_id) UNIQUE
#  index_events_on_tournament_id                (tournament_id)
#  index_events_on_tournament_id_and_game_slug  (tournament_id,game_slug) UNIQUE
#  index_events_on_winner_entrant_id            (winner_entrant_id)
#

class Event < ApplicationRecord
  STATE_ACTIVE = 'ACTIVE'
  STATE_COMPLETED = 'COMPLETED'

  SET_STATE_IN_PROGRESS = 2
  SET_STATE_COMPLETED = 3

  PLACEMENTS = [1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025]

  BRACKET_TYPE_DOUBLE_ELIMINATION = 'DOUBLE_ELIMINATION'

  ENTRANT_SYNC_BATCH_SIZE = 60

  belongs_to :tournament
  has_many :entrants
  has_many :players, through: :entrants
  belongs_to :winner_entrant, class_name: 'Entrant', optional: true
  has_one :winner_player, class_name: 'Player', through: :winner_entrant, source: :player
  belongs_to :game, foreign_key: :game_slug, primary_key: :slug
  has_many :notifications, as: :notifiable

  scope :should_sync_entrants, -> { where("coalesce(entrants_synced_at, now() - interval '1 day') - coalesce(player_count, 0) * interval '30 seconds' <= ?", 1.day.ago) }
  scope :in_progress, -> { where(state: STATE_ACTIVE) }

  # TODO: Put this somewhere else?
  def self.upset_factor(winner_seed:, loser_seed:)
    winner_seed_placement_index = PLACEMENTS.count { |placement| winner_seed >= placement } - 1
    loser_seed_placement_index = PLACEMENTS.count { |placement| loser_seed >= placement } - 1
    return winner_seed_placement_index - loser_seed_placement_index
  end

  def should_ingest?
    return false unless game&.ingestion_threshold.present?
    player_count.present? && player_count >= game.ingestion_threshold
  end

  def should_display?
    # Pseudo-cache of this, to keep events from falling off the radar after
    # we've sent notifications and stuff for them. This value can safely be set
    # to nil if we want to regenerate it based on new logic below.
    return should_display unless should_display.nil?

    return false unless game&.display_threshold.present?
    return true if tournament.override.present? && tournament.override.include
    return false unless player_count.present?

    # Ignore long tournaments because some TOs reuse the same tournament for
    # weeklies, ladders, etc.
    return false if tournament.end_at - tournament.start_at > 7.days

    # If the event is stacked with ranked players, always display it. This
    # should catch invitationals and stuff.
    if ranked_player_count.present? && ranked_player_count > 0 && player_count.present? && player_count >= 8
      return true if ranked_player_count.to_f / player_count.to_f > 0.4
      return true if ranked_player_count > 10
    end

    score = player_count + ((ranked_player_count || 0) * 10)
    score > game.display_threshold
  end

  # Meant to be used like: "Featuring #{event.entrants_sentence}"
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
    if is_seeded
      entrants.includes(:player, :player2).where('seed is not null').order(seed: :asc).limit(10)
    elsif ranked_player_count.present? && ranked_player_count > 0
      entrants.includes(:player, :player2).where('rank is not null').order(rank: :asc).limit(10)
    end
  end

  def featured_entrants_data
    Rails.cache.fetch("featured_entrants_data_#{id}", expires_in: Rails.env.development? ? 5.seconds : 1.hour) do
      featured_entrants&.map do |entrant|
        {
          tag: entrant.player&.tag,
          twitter_username: entrant.player&.twitter_username,
          player2_tag: entrant.player2&.tag,
          player2_twitter_username: entrant.player2&.twitter_username
        }
      end
    end
  end

  def startgg_url
    "https://start.gg/#{slug}"
  end

  def completed?
    state == STATE_COMPLETED
  end

  def sync_entrants!
    Rails.logger.info "Syncing entrants for #{tournament.slug} (#{game.slug})..."
    entrants = []
    stats = {
      created: 0,
      updated: 0,
      deleted: 0
    }

    # Get all the entrants, 1 chunk at a time
    (1..100).each do |page|
      event_entrants = Startgg.with_retries(5) do
        Startgg.event_entrants(
          id: startgg_id,
          game: game,
          batch_size: ENTRANT_SYNC_BATCH_SIZE,
          page:
        )
      end

      # Respect startgg's rate limits...
      sleep 1

      # This means the tournament was probably deleted.
      if event_entrants.nil?
        Rails.logger.info "Tournament #{tournament.slug} not found. Deleting..."
        StatsD.increment('startgg.tournament_deleted')
        tournament.destroy
        break
      end

      # This means there are no available entrants.
      break if event_entrants.count.zero?

      entrants = [*entrants, *event_entrants]

      # If we don't have a full batch, this is the last page.
      break if event_entrants.count != ENTRANT_SYNC_BATCH_SIZE
    end

    return stats if tournament.destroyed?

    # Populate entrants
    entrants = entrants.map do |entrant|
      entrant = Entrant.from_startgg_entrant(entrant, event: self)

      if !entrant.persisted?
        entrant.save!

        stats[:created] += 1
        StatsD.increment('startgg.entrant_added')
      elsif entrant.changed? || entrant.player_changed? || entrant.player2_changed?
        entrant.save!

        stats[:updated] += 1
        entrant.saved_changes.reject { |field, value| field == 'updated_at' }.each do |field, value|
          StatsD.increment("startgg.entrant_field_updated.#{field}")
        end
        StatsD.increment('startgg.entrant_updated')
      end

      entrant
    end

    # Delete entrants that are no longer registered
    self.entrants.where.not(id: entrants.map(&:id)).each do |entrant|
      entrant.destroy!

      stats[:deleted] += 1
      StatsD.increment('startgg.entrant_deleted')
    end

    # Denormalize whether the event is seeded
    self.is_seeded = entrants.any? { |entrant| entrant.seed.present? }

    # Denormalize ranked entrant count
    self.ranked_player_count = entrants.filter { |entrant| entrant.rank.present? }.count

    self.entrants_synced_at = Time.now
    save!

    stats
  end

  def initialize_twitter_upset_thread!
    return if last_upset_tweet_id.present?

    Rails.logger.info("Starting upset thread for #{slug} (#{game.slug})...")

    tweet = Twitter.upset_thread_intro(self)

    self.last_upset_tweet_id = tweet['data']['id']
    save!
  end

  def sync_sets!
    return if completed?

    start_time = Time.now

    sync_in_progress_sets!
    sync_completed_sets!

    self.sets_synced_at = start_time
    save!
  end

  def sync_in_progress_sets!
    batch_size = 20

    (1..1000).each do |page|
      sets = Startgg.with_retries(5, batch_size:) do |batch_size|
        Rails.logger.debug "Fetching in progress sets for #{tournament.slug} #{game.slug}..."

        Startgg.in_progress_sets(startgg_id, batch_size:, page:)
      end

      break if sets.blank?
      break if sets.count.zero?
      Rails.logger.debug "Found #{sets.count} in progress sets for #{tournament.slug} #{game.slug}. Analyzing..."

      sets.each do |set|
        StatsD.increment('startgg.set_fetched.in_progress')
        process_in_progress_set(set)
      end

      break if sets.count < batch_size

      sleep 1
    end
  end

  def sync_completed_sets!
    batch_size = 20

    (1..1000).each do |page|
      sets = Startgg.with_retries(5, batch_size:) do |batch_size|
        Rails.logger.debug "Fetching completed sets for #{tournament.slug} #{game.slug}..."

        Startgg.completed_sets(startgg_id, batch_size:, page:, updated_after: (sets_synced_at.present? ? sets_synced_at - 5.seconds : 1.hour.ago))
      end

      break if sets.blank?
      break if sets.count.zero?
      Rails.logger.debug "Found #{sets.count} updated completed sets for #{tournament.slug} #{game.slug}. Analyzing..."

      sets.each do |set|
        StatsD.increment('startgg.set_fetched.completed')
        process_completed_set(set)
      end

      break if sets.count < batch_size

      sleep 1
    end
  end

  def process_in_progress_set(set)
    # Most sets don't have a stream, so this filters a ton.
    return unless set.stream.present?
    return unless set.stream.stream_source.downcase == Tournament::STREAM_SOURCE_TWITCH

    # We only care about currently ongoing sets.
    return unless set.started_at.present?
    return unless set.completed_at.blank?

    # If the player records aren't set, we can't do anything.
    return unless set.slots&.first&.entrant&.participants&.first&.player&.present?
    return unless set.slots&.second&.entrant&.participants&.first&.player&.present?

    players = Player.where(startgg_player_id: [
      set.slots.first.entrant.participants.first.player.id,
      set.slots.second.entrant.participants.first.player.id
    ])

    # Let Setbot do its thing.
    players.each do |player|
      opponent = (players - [player]).first
      next unless opponent.present?

      Setbot.notify_subscriptions(
        event: self,
        player:,
        opponent:,
        stream_name: set.stream.stream_name,
        startgg_set_id: set.id
      )
    end

    # Now update the set Discord channels.
    player = players.first
    opponent = (players - [player]).first
    return unless opponent.present?

    previous_notification = Notification.where(
      notifiable: player,
      notification_type: Notification::TYPE_PLAYER_SET_LIVE,
      platform: Notification::PLATFORM_DISCORD,
      success: true
    ).order(sent_at: :desc).first

    return if previous_notification.present? && previous_notification.metadata.with_indifferent_access[:startgg_set_id].to_s == set.id.to_s

    Notification.send_notification(
      player,
      type: Notification::TYPE_PLAYER_SET_LIVE,
      platform: Notification::PLATFORM_DISCORD,
      metadata: { startgg_set_id: set.id }
    ) do |player|
      Discord.player_set_live(
        event: self,
        player:,
        opponent:,
        stream_name: set.stream.stream_name
      )
    end
  end

  def process_completed_set(set)
    return unless set.winner_id.present?
    return unless set.phase_group&.bracket_type == BRACKET_TYPE_DOUBLE_ELIMINATION

    entrant_startgg_ids = set.slots.map(&:entrant).map(&:id).map(&:to_s)
    return unless entrant_startgg_ids.count == 2

    winner_entrant = entrants.find_by(startgg_entrant_id: set.winner_id)
    return unless winner_entrant.present? && winner_entrant.seed.present?

    loser_entrant = entrants.find_by(startgg_entrant_id: (entrant_startgg_ids - [set.winner_id.to_s]).first)
    return unless loser_entrant.present? && loser_entrant.seed.present?

    # Larger events don't really seed beyond top 256 typically, so upsets
    # beyond that don't really mean anything.
    return unless loser_entrant.seed <= 256

    upset_factor = self.class.upset_factor(
      winner_seed: winner_entrant.seed,
      loser_seed: loser_entrant.seed
    )

    game_counts = set.slots.reduce({}) do |counts, slot|
      counts[slot.entrant.id.to_s] = slot.standing&.stats&.score&.value&.to_i
      counts
    end

    winner_games = game_counts[winner_entrant.startgg_entrant_id.to_s]
    loser_games = game_counts[loser_entrant.startgg_entrant_id.to_s]

    return unless winner_games.present? && loser_games.present? && winner_games > -1 && loser_games > -1

    if upset_factor > 2
      initialize_twitter_upset_thread!

      previous_notification = Notification.where(
        notifiable: self,
        notification_type: Notification::TYPE_UPSET,
        platform: Notification::PLATFORM_TWITTER,
        success: true
      ).filter { |notification| notification.metadata.with_indifferent_access[:startgg_set_id].to_s == set.id.to_s }.first

      return if previous_notification.present?

      upset_factor = Event.upset_factor(winner_seed: winner_entrant.seed, loser_seed: loser_entrant.seed)
      Rails.logger.info("Posting upset tweet for #{winner_entrant.tag} (#{winner_entrant.seed}) #{winner_games}-#{loser_games} #{loser_entrant.tag} (#{loser_entrant.seed}) [UF #{upset_factor}")

      Notification.send_notification(
        self,
        type: Notification::TYPE_UPSET,
        platform: Notification::PLATFORM_TWITTER,
        metadata: { startgg_set_id: set.id }
      ) do |event|
        tweet = Twitter.upset(
          event: event,
          winner_entrant:,
          winner_games:,
          loser_entrant:,
          loser_games:
        )

        self.last_upset_tweet_id = tweet['data']['id']
        save!

        sleep 1
      end
    end
  end
end
