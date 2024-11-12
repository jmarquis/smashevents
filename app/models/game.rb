# == Schema Information
#
# Table name: games
#
#  id                  :integer          not null, primary key
#  slug                :string
#  name                :string
#  twitch_name         :string
#  startgg_id          :integer
#  rankings_regex      :string
#  ingestion_threshold :integer
#  display_threshold   :integer
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
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
