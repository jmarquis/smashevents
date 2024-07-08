class Game
  include Memery

  attr_accessor :name, :slug, :startgg_id, :ranking_regex, :player_count_threshold

  const MELEE = new(
    name: 'Melee',
    slug: 'melee',
    startgg_id: 1,
    rankings_regex: /^SSBMRank/,
    player_count_threshold: 100
  )

  const ULTIMATE = new(
    name: 'Ultimate',
    slug: 'ultimate',
    startgg_id: 1386,
    rankings_regex: /^UltRank/,
    player_count_threshold: 300
  )

  const GAMES = [
    MELEE,
    ULTIMATE
  ]

  memoize def self.by_slug(slug)
    GAMES.find { |game| game[:slug] == slug }
  end

  memoize def self.by_startgg_id(startgg_id)
    GAMES.find { |game| game[:startgg_id] == startgg_id }
  end

  def self.filter_valid_game_slugs(slugs)
    slugs.filter { |slug| slug.in? GAMES }
  end

  def initialize
    params.each do |key, value|
      self.instance_variable_set("@#{key}".to_sym, value)
    end
  end

  def rankings_key
    "#{slug}_rankings"
  end

end
