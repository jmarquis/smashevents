class GameConfig

  GAMES = {
    MELEE[:slug] => MELEE
  }

  MELEE = {
    name: 'Melee',
    slug: 'melee',
    startgg_id: 1,
    ranking_regex: /^SSBMRank/
  }

  def self.filter_valid_games(games)
    games.filter { |game| game.in? GAMES }
  end

end
