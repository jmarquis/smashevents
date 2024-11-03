# == Schema Information
#
# Table name: games
#
#  id                  :bigint           not null, primary key
#  display_threshold   :integer
#  ingestion_threshold :integer
#  name                :string
#  rankings_regex      :string
#  slug                :string
#  twitch_name         :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  startgg_id          :integer
#
# Indexes
#
#  index_games_on_slug         (slug)
#  index_games_on_startgg_id   (startgg_id)
#  index_games_on_twitch_name  (twitch_name)
#
class Game < ApplicationRecord

  scope :all_games_except, ->(games) { where.not(slug: games.map(&:slug)) }

  def self.filter_valid_game_slugs(slugs)
    all_slugs = Game.pluck(:slug)
    slugs.filter { |slug| slug.in? all_slugs }.uniq
  end

  def rankings_key
    "#{slug}_rankings"
  end
end
