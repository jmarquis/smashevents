# == Schema Information
#
# Table name: tournament_games
#
#  id               :bigint           not null, primary key
#  featured_players :string           is an Array
#  game             :string           not null
#  player_count     :integer
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  startgg_id       :integer          not null
#  tournament_id    :bigint           not null
#
# Indexes
#
#  index_tournament_games_on_startgg_id              (startgg_id) UNIQUE
#  index_tournament_games_on_tournament_id           (tournament_id)
#  index_tournament_games_on_tournament_id_and_game  (tournament_id,game) UNIQUE
#
class TournamentGame < ApplicationRecord
  belongs_to :tournament

  def interesting?
    player_count.present? && player_count > GameConfig::GAMES[game][:player_count_threshold]
  end
end
