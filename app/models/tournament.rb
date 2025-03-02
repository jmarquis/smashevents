# == Schema Information
#
# Table name: tournaments
#
#  id                :integer          not null, primary key
#  startgg_id        :integer
#  slug              :string
#  name              :string
#  start_at          :datetime
#  end_at            :datetime
#  city              :string
#  state             :string
#  country           :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  stream_data       :json
#  timezone          :string
#  hashtag           :string
#  banner_image_url  :string
#  profile_image_url :string
#
# Indexes
#
#  index_tournaments_on_name        (name)
#  index_tournaments_on_start_at    (start_at)
#  index_tournaments_on_startgg_id  (startgg_id) UNIQUE
#

class Tournament < ApplicationRecord
  STREAM_SOURCE_TWITCH = 'twitch'
  STREAM_SOURCE_YOUTUBE = 'youtube'

  STREAM_STATUS_LIVE = 'live'

  has_many :events, dependent: :destroy
  has_many :notifications, as: :notifiable
  has_one :override, class_name: 'TournamentOverride', foreign_key: :slug, primary_key: :slug

  scope :upcoming, -> { where('end_at >= ?', Date.today) }

  def self.from_startgg_tournament(data)
    t = find_by(startgg_id: data.id) || new

    t.startgg_id = data.id
    t.slug = data.slug.match(/^tournament\/(.*)/)[1]
    t.name = data.name
    t.hashtag = data.hashtag
    t.start_at = data.start_at.present? ? Time.at(data.start_at) : nil
    t.end_at = data.end_at.present? ? Time.at(data.end_at) : nil
    t.timezone = data.timezone
    t.city = data.city
    t.state = data.addr_state
    t.country = data.country_code
    t.banner_image_url = data.images.blank? ? nil : data.images
      .filter { |image| image.type == 'banner' }
      .map { |image| image.url.gsub(/\?.*/, '') }
      .first

    t.profile_image_url = data.images.blank? ? nil : data.images
      .filter { |image| image.type == 'profile' }
      .map { |image| image.url.gsub(/\?.*/, '') }
      .first

    t.stream_data = data.streams&.map do |stream|
      stream_data = (t.stream_data || []).map(&:deep_symbolize_keys).find { |data| data[:name]&.downcase == stream.stream_name.downcase } || {}

      stream_data[:name] = stream.stream_name
      stream_data[:source] = stream.stream_source

      stream_data
    end

    events = []
    Game.all.each do |game|
      biggest_event = (data.events || [])
        .filter { |event| event.videogame.id.to_i == game.startgg_id }
        # Some TOs make a single tournament for a weekly for some reason, and
        # just move the tournament's start_at and end_at every week. So make
        # sure we don't consider old events part of the current tournament.
        .filter { |event| Time.at(event.start_at) >= t.start_at }
        .max { |a, b| a.num_entrants <=> b.num_entrants }

      if biggest_event.present?
        # Look up by game because we only care about one event per game per
        # tournament.
        event = t.events.find_by(game:) || t.events.new

        event.startgg_id = biggest_event.id
        event.slug = biggest_event.slug
        event.state = biggest_event.state
        event.start_at = Time.at(biggest_event.start_at)
        event.game = game
        event.player_count = biggest_event.num_entrants

        winner_data = biggest_event.standings&.nodes&.first&.entrant
        if event.state == Event::STATE_COMPLETED && winner_data.present?
          winner_entrant = event.entrants&.find_by(startgg_entrant_id: winner_data.id)
          event.winner_entrant = winner_entrant if winner_entrant.present?
        else
          event.winner_entrant = nil
        end

        events << event
      end
    end

    return t, events
  end

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

  def startgg_data
    Startgg.tournament(slug:)
  end

  def sync
    tournament, events = Tournament.from_startgg_tournament(startgg_data)

    tournament.save!
    events.each(&:save!)

    reload
    self
  end

  def sync_entrants
    events.each(&:sync_entrants)
  end

end
