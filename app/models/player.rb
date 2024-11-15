# == Schema Information
#
# Table name: players
#
#  id                :integer          not null, primary key
#  startgg_player_id :integer
#  startgg_user_id   :integer
#  tag               :string
#  twitter_username  :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
# Indexes
#
#  index_players_on_startgg_player_id  (startgg_player_id) UNIQUE
#  index_players_on_startgg_user_id    (startgg_user_id) UNIQUE
#  index_players_on_tag                (tag)
#

class Player < ApplicationRecord

  TWITTER_USERNAME_FALLBACKS = {
    'chem' => 'Chemjamin',
    'fiction' => 'FictionIRL',
    'junebug' => 'arJunebug',
    'mang0' => 'C9Mang0',
    'mvlvchi' => '_mvlvchi_',
    'wizzrobe' => 'Wizzrobe',
    'plup' => 'Plup_Club',
  }

  has_many :entrants
  has_many :events, through: :entrants

  before_save :set_defaults

  def set_defaults
    self.twitter_username ||= TWITTER_USERNAME_FALLBACKS[tag.downcase]
  end

  def self.from_json(serialized_player)
    new(JSON.parse(serialized_player).deep_symbolize_keys)
  rescue JSON::ParserError
    new(tag: serialized_player)
  end

  def self.from_startgg(data)
    p = find_by(startgg_player_id: data.id) || new

    p.startgg_player_id = data.id
    p.startgg_user_id = data.user&.id
    p.tag = data.gamer_tag
    p.twitter_username = data&.user&.authorizations&.first&.external_username

    p
  end

  def serialize
    {
      tag:,
      twitter_username:
    }.to_json
  end

  def twitter_url
    "https://twitter.com/#{twitter_username}" if twitter_username.present?
  end

end
