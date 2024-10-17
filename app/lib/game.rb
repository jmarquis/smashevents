class Game
  attr_accessor :name, :slug, :twitch_name, :startgg_id, :rankings_regex, :ingestion_threshold, :display_threshold

  def initialize(params)
    params.each do |key, value|
      self.instance_variable_set("@#{key}".to_sym, value)
    end
  end

  MELEE = new(
    slug: 'melee',
    name: 'Melee',
    twitch_name: 'Super Smash Bros. Melee',
    startgg_id: 1,
    rankings_regex: /^SSBMRank/,
    ingestion_threshold: 8,
    display_threshold: 100
  )

  ULTIMATE = new(
    slug: 'ultimate',
    name: 'Ultimate',
    twitch_name: 'Super Smash Bros. Ultimate',
    startgg_id: 1386,
    rankings_regex: /^UltRank/,
    ingestion_threshold: 8,
    display_threshold: 200
  )

  SMASH64 = new(
    slug: 'smash64',
    name: 'Smash 64',
    twitch_name: 'Super Smash Bros.',
    startgg_id: 4,
    rankings_regex: /^The SSB64 League Rankings/,
    ingestion_threshold: 8,
    display_threshold: 30
  )

  RIVALS = new(
    slug: 'rivals',
    name: 'Rivals',
    twitch_name: 'Rivals of Aether',
    startgg_id: 24,
    rankings_regex: /^NA RCS/,
    ingestion_threshold: 8,
    display_threshold: 40
  )

  RIVALS2 = new(
    slug: 'rivals2',
    name: 'Rivals 2',
    twitch_name: 'Rivals 2',
    startgg_id: 53945,
    rankings_regex: /^NA RCS/,
    ingestion_threshold: 8,
    display_threshold: 60
  )

  GAMES = [
    MELEE,
    ULTIMATE,
    SMASH64,
    RIVALS,
    RIVALS2
  ]

  class << self
    include Memery

    memoize def by_slug(slug)
      GAMES.find { |game| game.slug == slug.to_s }
    end

    memoize def by_twitch_name(twitch_name)
      GAMES.find { |game| game.twitch_name == twitch_name }
    end

    memoize def by_startgg_id(startgg_id)
      GAMES.find { |game| game.startgg_id == startgg_id }
    end

    def all_games_except(games)
      GAMES.reject { |game| game.slug.in? games.map(&:slug) }
    end

    def filter_valid_game_slugs(slugs)
      slugs.filter { |slug| slug.in? GAMES.map(&:slug) }.uniq
    end
  end

  def rankings_key
    "#{slug}_rankings"
  end

end
