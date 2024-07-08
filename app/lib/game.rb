class Game
  attr_accessor :name, :slug, :startgg_id, :ranking_regex, :player_count_threshold

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

  GAMES = [
    MELEE,
    ULTIMATE
  ]

  class << self
    include Memery

    memoize def by_slug(slug)
      GAMES.find { |game| game.slug == slug }
    end

    memoize def by_startgg_id(startgg_id)
      GAMES.find { |game| game.startgg_id == startgg_id }
    end
  end

  def self.filter_valid_game_slugs(slugs)
    slugs.filter { |slug| slug.in? GAMES }
  end

  def rankings_key
    "#{slug}_rankings"
  end

end
