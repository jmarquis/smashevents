class GameConfig

  MELEE = {
    name: 'Melee',
    slug: 'melee',
    startgg_id: 1,
    ranking_regex: /^SSBMRank/,
    player_count_threshold: 100
  }

  ULTIMATE = {
    name: 'Ultimate',
    slug: 'ultimate',
    startgg_id: 1386,
    ranking_regex: /^UltRank/,
    player_count_threshold: 300
  }

  GAMES = {
    MELEE[:slug] => MELEE,
    ULTIMATE[:slug] => ULTIMATE
  }

  def self.filter_valid_games(games)
    games.filter { |game| game.in? GAMES }
  end

end
