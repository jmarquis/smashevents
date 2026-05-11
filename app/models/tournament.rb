# == Schema Information
#
# Table name: tournaments
#
#  id                     :integer          not null, primary key
#  provider_tournament_id :integer
#  slug                   :string
#  name                   :string
#  start_at               :datetime
#  end_at                 :datetime
#  city                   :string
#  state                  :string
#  country                :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  stream_data            :json
#  timezone               :string
#  hashtag                :string
#  banner_image_url       :string
#  profile_image_url      :string
#  provider               :string
#
# Indexes
#
#  index_tournaments_on_name                                 (name)
#  index_tournaments_on_provider_and_provider_tournament_id  (provider,provider_tournament_id) UNIQUE
#  index_tournaments_on_start_at                             (start_at)
#

class Tournament < ApplicationRecord
  STREAM_SOURCE_TWITCH = 'twitch'
  STREAM_SOURCE_YOUTUBE = 'youtube'

  STREAM_STATUS_LIVE = 'live'

  has_many :events, dependent: :destroy
  has_many :notifications, as: :notifiable
  has_one :override, class_name: 'TournamentOverride', foreign_key: :slug, primary_key: :slug

  scope :not_past, -> { where('end_at >= ?', Date.today) }
  scope :in_progress, -> {
    includes(:events)
      .where('tournaments.start_at <= ? and end_at >= ?', Time.now, Time.now - 12.hours)
      .where(events: { winner_entrant_id: nil })
  }
  scope :reasonable_duration, -> { where("end_at - start_at < interval '7 days'") }
  scope :has_streams, -> { where.not(stream_data: nil) }
  scope :should_display, ->(games: Game.all.map(&:slug)) {
    includes(:override, events: [:game, winner_entrant: :player])
      .where(events: { game: games })
      .merge(
        where(events: { should_display: true })
          .or(
            where(override: { include: true }).or(
              where("end_at - tournaments.start_at <= interval '7 days'").merge(
                where.not(events: { player_count: nil }).merge(
                  where('coalesce(events.player_count, 0) >= 8').merge(
                    where('coalesce(events.ranked_player_count, 0)::float / case when coalesce(events.player_count, 1) = 0 then 1.0 else coalesce(events.player_count, 1)::float end > ?', 0.3).or(
                      where('events.ranked_player_count > ?', 10)
                    ).or(
                        where('coalesce(events.player_count, 0) + (coalesce(events.ranked_player_count, 0) * 10) > games.display_threshold')
                      )
                  )
                )
              )
            )
          )
      )
  }

  def should_ingest?
    return override.include unless override&.include.nil?

    Game.all.each do |game|
      event = events.find_by(game:)
      return true if event.present? && event.should_ingest?
    end

    false
  end

  def should_display?(game_slugs: Game.pluck(:slug))
    return false if events.find_by(game_slug: game_slugs).blank?

    return override.include unless override&.include.blank?

    # Ignore long tournaments because some TOs reuse the same tournament for
    # weeklies, ladders, etc.
    return false if end_at - start_at > 7.days

    game_slugs.each do |game_slug|
      event = events.find_by(game_slug:)
      return true if event.present? && event.should_display?
    end

    false
  end

  def exclude?
    override = TournamentOverride.find_by(slug:)
    override&.include == false
  end

  def adjusted_start_at
    start_at.in_time_zone(timezone || 'America/New_York')
  end

  def adjusted_end_at
    # Subtract a second because a lot of people set their tournaments to stop
    # at midnight, which is technically the next day.
    end_at.in_time_zone(timezone || 'America/New_York') - 1.second
  end

  def formatted_date_range
    if adjusted_start_at.day == adjusted_end_at.day
      adjusted_start_at.strftime('%b %-d, %Y')
    elsif adjusted_start_at.month == adjusted_end_at.month
      "#{adjusted_start_at.strftime('%b %-d')} – #{adjusted_end_at.strftime('%-d, %Y')}"
    elsif adjusted_start_at.year == adjusted_end_at.year
      "#{adjusted_start_at.strftime('%b %-d')} – #{adjusted_end_at.strftime('%b %-d, %Y')}"
    else
      "#{adjusted_start_at.strftime('%b %-d, %Y')} – #{adjusted_end_at.strftime('%b %-d, %Y')}"
    end
  end

  # Fri - Sun  or  Saturday
  def formatted_day_range
    if adjusted_start_at.day == adjusted_end_at.day
      adjusted_start_at.strftime('%A')
    else
      "#{adjusted_start_at.strftime('%a')} – #{adjusted_end_at.strftime('%a')}"
    end
  end

  def formatted_location
    return 'Online' if city.blank? && state.blank? && country.blank?
    [city, state, country.in?(['US', 'GB']) ? nil : country].compact.join(', ')
  end

  def banner_image_extension
    return nil if banner_image_url.blank?

    banner_image_url.match(/\.([^.]*)$/)[1]
  end

  def banner_image_file
    return nil if banner_image_url.blank?

    path = "./tmp/#{SecureRandom.hex}.#{banner_image_extension}"
    IO.copy_stream(URI.open(banner_image_url), path)

    path
  end

  def past?
    end_at.present? && Time.now - 6.hours > end_at
  end

  def provider_data
    Provider::Base.provider(provider).tournament(slug:)
  end

  def sync
    tournament, events = factory.tournament(provider_data)

    tournament.save!
    events.each(&:save!)

    reload
    self
  end

  def sync_entrants!
    events.each(&:sync_entrants!)
  end

  def has_streams?
    stream_data.present?
  end

  def in_progress?
    return false unless start_at <= Time.now && end_at + 12.hours >= Time.now
    return false unless events.any? { |e| e.winner_entrant_id.blank? }
    true
  end

  def starting_soon?
    return false if in_progress?
    return false if past?
    return false unless events.any? { |e| e.winner_entrant_id.blank? }
    start_at < Time.now + 8.hours
  end

  def completed?
    events.all?(&:completed?)
  end

  private

  def factory
    Factory::Base.factory(provider)
  end

end
