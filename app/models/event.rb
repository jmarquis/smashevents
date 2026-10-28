# == Schema Information
#
# Table name: events
#
#  id                  :bigint           not null, primary key
#  entrant_count       :integer
#  entrant_size        :integer
#  entrants_synced_at  :datetime
#  game_slug           :string           not null
#  is_seeded           :boolean
#  name                :string
#  ranked_player_count :integer
#  real_player_count   :integer
#  sets_synced_at      :datetime
#  should_display      :boolean
#  slug                :string
#  start_at            :datetime
#  state               :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  last_upset_tweet_id :string
#  provider_event_id   :string           not null
#  tournament_id       :bigint           not null
#  winner_entrant_id   :bigint
#
# Indexes
#
#  index_events_on_provider_event_id  (provider_event_id) UNIQUE
#  index_events_on_tournament_id      (tournament_id)
#  index_events_on_winner_entrant_id  (winner_entrant_id)
#

class Event < ApplicationRecord
  STATE_CREATED = 'CREATED'
  STATE_ACTIVE = 'ACTIVE'
  STATE_COMPLETED = 'COMPLETED'
  STATE_READY = 'READY'

  SET_STATE_IN_PROGRESS = 2
  SET_STATE_COMPLETED = 3

  belongs_to :tournament, touch: true
  has_many :entrants, dependent: :destroy
  has_many :players, through: :entrants
  belongs_to :winner_entrant, class_name: 'Entrant', optional: true
  has_one :winner_player, class_name: 'Player', through: :winner_entrant, source: :player
  belongs_to :game, foreign_key: :game_slug, primary_key: :slug
  has_many :notifications, as: :notifiable
  has_many :event_sets, dependent: :destroy

  scope :should_sync_entrants, -> {
    where("coalesce(entrants_synced_at, now() - interval '1 day') - coalesce(entrant_count, 0) * interval '30 seconds' <= ?", 1.day.ago)
      .or(in_progress.where('entrants_synced_at < start_at'))
      .or(in_progress.where(is_seeded: false))
  }
  scope :in_progress, -> { where(state: STATE_ACTIVE) }

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
    return false unless player_count.present?

    # Ignore long tournaments because some TOs reuse the same tournament for
    # weeklies, ladders, etc.
    return false if tournament.end_at - tournament.start_at > 7.days

    # If the event is stacked with ranked players, always display it. This
    # should catch invitationals and stuff.
    if ranked_player_count.present? && ranked_player_count > 0 && player_count.present? && player_count >= 8
      return true if ranked_player_count.to_f / player_count.to_f >= 0.25
      return true if ranked_player_count >= 8
    end

    # If an event only has player stubs, it's probably a test event or some kind
    # of preliminary thing we don't care about. A nil count means entrants
    # haven't been synced yet, so ignore that.
    return false if real_player_count&.zero?

    score = player_count + ((ranked_player_count || 0) * 10)
    score > game.display_threshold
  end

  def tournament_has_other_events_for_game?(should_display: true)
    Rails.cache.fetch("tournament_has_other_events_for_game_#{id}_should_display_#{should_display}", expires_in: Rails.env.development? ? 5.seconds : 1.day) do
      if should_display
        tournament.events.where(game_slug: game.slug).where.not(id:).filter(&:should_display?).any?
      else
        tournament.events.where(game_slug: game.slug).where.not(id:).any?
      end
    end
  end

  def display_name(should_display: true)
    return name if name.present? && tournament_has_other_events_for_game?(should_display:)

    "#{game.name} #{bracket_label}"
  end

  def bracket_label
    return 'Doubles' if entrant_size == 2

    'Singles'
  end

  def player_count
    (entrant_count || 0) * (entrant_size || 1)
  end

  # Meant to be used like: "Featuring #{event.entrants_sentence}"
  def entrants_sentence(twitter: false, show_count: true)
    entrants = featured_entrants
    if entrants.present?
      remaining_entrant_count = entrant_count - entrants.count

      entrants_tags = entrants.map { |entrant| entrant.tag(twitter:) }

      if show_count && remaining_entrant_count >= 10
        [*entrants_tags, "#{player_count - (entrants.count * (entrant_size || 1))} more!"].to_sentence
      else
        [*entrants_tags, 'more!'].to_sentence
      end
    elsif show_count
      "#{player_count} players!"
    end
  end

  def featured_entrants
    total_featured = entrant_count == 16 ? 16 : 10
    if is_seeded
      entrants.includes(:player, :player2).where('seed is not null').order(seed: :asc).limit(total_featured)
    elsif ranked_player_count.present? && ranked_player_count > 0
      entrants.includes(:player, :player2).where('rank is not null').order(rank: :asc).limit(total_featured)
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

  def url
    [provider.base_url, slug].join('/')
  end

  def completed?
    state == STATE_COMPLETED
  end

  def in_progress?
    state == STATE_ACTIVE
  end

  def sync_entrants!
    Rails.logger.info "Syncing entrants for #{tournament.slug} (#{game.slug})..."
    entrants = []
    stats = {
      created: 0,
      updated: 0,
      deleted: 0
    }

    cursor = nil

    # Get all the entrants, 1 chunk at a time
    (1..1000).each do |page|
      event_entrants, cursor = provider.event_entrants(
        provider_event_id:,
        game:,
        page:,
        cursor:
      )

      # Respect provider rate limits...
      sleep provider.sleep_time

      # This means the tournament was probably deleted, but let's double check
      # in case it was some weird API error or something.
      if event_entrants.nil?
        if provider.tournament(slug: tournament.slug).nil?
          Rails.logger.info "Tournament #{tournament.slug} not found. Deleting..."
          StatsD.increment("#{provider::PROVIDER_NAME}.tournament_deleted")
          tournament.destroy
        end

        break
      end

      # This means there are no available entrants, or we reached the end of the list.
      break if event_entrants.count.zero?

      entrants = [*entrants, *event_entrants]
    end

    return stats if tournament.destroyed?

    # Populate entrants
    entrants = entrants.map do |entrant|
      entrant = factory.entrant(entrant, event: self)

      if !entrant.persisted?
        entrant.save!

        stats[:created] += 1
        StatsD.increment("#{tournament.provider}.entrant_added")
      elsif entrant.changed? || entrant.player&.changed? || entrant.player2&.changed?
        entrant.save!
        entrant.player&.save!
        entrant.player2&.save!

        stats[:updated] += 1
        entrant.saved_changes.reject { |field, _value| field == 'updated_at' }.each_key do |field|
          StatsD.increment("#{tournament.provider}.entrant_field_updated.#{field}")
        end
        if entrant.player.present?
          entrant.player.saved_changes.reject { |field, _value| field == 'updated_at' }.each_key do |field|
            StatsD.increment("#{tournament.provider}.player_field_updated.#{field}")
          end
        end
        if entrant.player2.present?
          entrant.player2.saved_changes.reject { |field, _value| field == 'updated_at' }.each_key do |field|
            StatsD.increment("#{tournament.provider}.player_field_updated.#{field}")
          end
        end
        StatsD.increment("#{tournament.provider}.entrant_updated")
      end

      entrant
    end

    # Delete entrants that are no longer registered
    self.entrants.where.not(id: entrants.map(&:id)).each do |entrant|
      entrant.destroy!

      stats[:deleted] += 1
      StatsD.increment("#{tournament.provider}.entrant_deleted")
    end

    # Denormalize whether the event is seeded
    self.is_seeded = entrants.any? { |entrant| entrant.seed.present? }

    # Denormalize ranked entrant count
    self.ranked_player_count = entrants.filter { |entrant| entrant.rank.present? }.count

    # Denormalize count of players with real accounts (i.e. not stubs)
    self.real_player_count = entrants.sum do |entrant|
      [entrant.player, entrant.player2].count { |player| player&.provider_user_id.present? }
    end

    self.entrants_synced_at = Time.now
    save!

    stats
  end

  def upset_factor_threshold
    return 3 if player_count <= 1000

    4
  end

  def initialize_twitter_upset_thread!
    return if last_upset_tweet_id.present?

    Rails.logger.info("Starting upset thread for #{slug} (#{game.slug})...")

    tweet = Twitter::Gateway.upset_thread_intro(self)

    self.last_upset_tweet_id = tweet['data']['id']
    save!
  end

  def sync_state!
    event_state = provider.event_state(provider_event_id:)

    return unless event_state.present?

    self.state = event_state
    save! if state_changed?
  end

  def sync_sets!
    start_time = Time.now

    sync_in_progress_sets!

    # We only want to do anything with completed sets (i.e. upset threads) if
    # the event meets its game's display threshold. We don't do this check for
    # in-progress sets because Setbot notifications should go out regardless of
    # thresholds.
    sync_completed_sets! if should_display?

    self.sets_synced_at = start_time
    save!(touch: false)
  end

  def sync_in_progress_sets!
    (1..1000).each do |page|
      Rails.logger.debug "Fetching in progress sets for #{tournament.slug} #{game.slug}..."

      sets = provider.in_progress_sets(provider_event_id:, batch_size: 20, page:)

      break if sets.blank?
      break if sets.count.zero?

      Rails.logger.debug "Found #{sets.count} in progress sets for #{tournament.slug} #{game.slug}. Analyzing..."

      sets.each do |set|
        StatsD.increment("#{provider::PROVIDER_NAME}.set_fetched.in_progress")
        set = factory.set(set, event: self)

        next unless set.entrant1.present? && set.entrant2.present?

        set.save!

        process_in_progress_set(set)
      end

      sleep provider.sleep_time
    end
  end

  def sync_completed_sets!
    (1..1000).each do |page|
      Rails.logger.debug "Fetching completed sets for #{tournament.slug} #{game.slug}..."

      sets = provider.completed_sets(provider_event_id:, batch_size: 20, page:, updated_after: (sets_synced_at.present? ? sets_synced_at - 1.minute : 1.hour.ago))

      break if sets.blank?
      break if sets.count.zero?

      Rails.logger.debug "Found #{sets.count} updated completed sets for #{tournament.slug} #{game.slug}. Analyzing..."

      sets.each do |set|
        StatsD.increment("#{provider::PROVIDER_NAME}.set_fetched.completed")
        set = factory.set(set, event: self)

        next unless set.entrant1.present? && set.entrant2.present?

        set.save!

        process_completed_set(set)
      end

      sleep provider.sleep_time
    end
  end

  def process_in_progress_set(set)
    # Most sets don't have a stream, so this filters a ton.
    return unless set.stream.present?
    return unless set.stream.platform == Stream::PLATFORM_TWITCH

    # We only care about currently ongoing sets.
    return unless set.started_at.present?
    return unless set.completed_at.blank?

    # If the player records aren't set, we can't do anything.
    return unless set.entrant1&.player.present?
    return unless set.entrant2&.player.present?

    # If the stream isn't actually live, we're not going to notify about it.
    # Probably the TO intended to stream it but for whatever reason the set
    # started before the stream started.
    return unless set.stream.live?

    # Let Setbot do its thing.
    Setbot.notify_subscriptions(set:)

    # At this point we may have an event that doesn't meet its game's display
    # threshold but is syncing sets because it has an entrant with an associated
    # PlayerSubscription, which we would have notified about just above via
    # Setbot.notify_subscriptions. But we don't want to do other notifications
    # for this, so exit here.
    return unless should_display?

    # Now update the set Discord channels.
    Notification.send_notification(
      set,
      type: Notification::TYPE_PLAYER_SET_LIVE,
      platform: Notification::PLATFORM_DISCORD,
      idempotent: true
    ) do |set|
      Discord::Gateway.set_live(set:)
    end
  end

  def process_completed_set(set)
    return unless set.winner_entrant.present?
    return unless set.entrant1&.seed.present?
    return unless set.entrant2&.seed.present?
    return unless set.entrant1_score.present?
    return unless set.entrant2_score.present?
    return unless set.entrant1_score > -1
    return unless set.entrant2_score > -1

    # Larger events don't really seed beyond top 256 typically, so upsets
    # beyond that don't really mean anything.
    return unless set.loser_entrant.seed <= 256

    # We don't report every upset, just the bigger ones.
    return unless set.upset_factor >= upset_factor_threshold

    initialize_twitter_upset_thread!

    Notification.send_notification(
      set,
      type: Notification::TYPE_UPSET,
      platform: Notification::PLATFORM_TWITTER,
      idempotent: true
    ) do |set|
      Rails.logger.info("Posting upset tweet for #{set.winner_entrant.tag} (#{set.winner_entrant.seed}) #{set.winner_score}-#{set.loser_score} #{set.loser_entrant.tag} (#{set.loser_entrant.seed}) [UF #{set.upset_factor}]")

      tweet = Twitter::Gateway.upset(set:)

      self.last_upset_tweet_id = tweet['data']['id']
      save!

      sleep 1
    end
  end

  def provider
    Provider.provider(tournament.provider)
  end

  def factory
    Factory.factory(tournament.provider)
  end
end
