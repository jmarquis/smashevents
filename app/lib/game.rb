class Game
  attr_accessor :name, :slug, :startgg_id, :rankings_regex, :player_count_threshold

  def initialize(params)
    params.each do |key, value|
      self.instance_variable_set("@#{key}".to_sym, value)
    end
  end

  MELEE = new(
    name: 'Melee',
    slug: 'melee',
    startgg_id: 1,
    rankings_regex: /^SSBMRank/,
    player_count_threshold: 100
  )

  ULTIMATE = new(
    name: 'Ultimate',
    slug: 'ultimate',
    startgg_id: 1386,
    rankings_regex: /^UltRank/,
    player_count_threshold: 300
  )

  SMASH64 = new(
    name: 'Smash 64',
    slug: 'smash64',
    startgg_id: 4,
    rankings_regex: /^The SSB64 League Rankings/,
    player_count_threshold: 20
  )

  RIVALS = new(
    name: 'Rivals',
    slug: 'rivals',
    startgg_id: 24,
    rankings_regex: /^NA RCS/,
    player_count_threshold: 30
  )

  RIVALS2 = new(
    name: 'Rivals 2',
    slug: 'rivals2',
    startgg_id: 53945,
    rankings_regex: /^NA RCS/,
    player_count_threshold: 30
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
      GAMES.find { |game| game.slug == slug }
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
