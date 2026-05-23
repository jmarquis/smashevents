# == Schema Information
#
# Table name: players
#
#  id                 :bigint           not null, primary key
#  name               :string
#  provider           :string
#  provider_user_slug :string
#  tag                :string
#  twitter_username   :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  provider_player_id :string
#  provider_user_id   :string
#
# Indexes
#
#  gin_index_players_on_tag                          (tag) USING gin
#  index_players_on_provider_and_provider_player_id  (provider,provider_player_id) UNIQUE
#  index_players_on_provider_and_provider_user_id    (provider,provider_user_id) UNIQUE
#  index_players_on_provider_user_slug               (provider_user_slug)
#  index_players_on_tag                              (tag)
#

class Player < ApplicationRecord

  TWITTER_USERNAME_FALLBACKS = {
    'chem' => 'Chemjamin',
    'drephen' => 'Drephen',
    'faust' => 'FaustSSBM',
    'fiction' => 'FictionIRL',
    'grab' => 'DthrowDtilt',
    'isai' => 'IsaiAlvaradoSSB',
    'jmook' => 'jakedirado',
    'junebug' => 'arJunebug',
    'kerokeroppi' => 'KeroKeroppi64',
    'kurabba' => 'Kurabba',
    'mang0' => 'C9Mang0',
    'mvlvchi' => '_mvlvchi_',
    'pewpewu' => '_PewPewU',
    'plup' => 'Plup_Club',
    'rapmonster' => 'Rap1238727',
    'sirmeris' => 'sirmeris',
    'soonsay' => 's00nsay',
    'stango' => 'StangoSSBM',
    'superboomfan' => 'SuPeRbOoMfAnSSB',
    'wizzrobe' => 'Wizzrobe',
    'zain' => 'ZainNaghmi',
  }

  has_many :entrants
  has_many :events, through: :entrants

  scope :tag_similar_to, lambda { |query|
    quoted_query = ActiveRecord::Base.connection.quote_string(query)
    where('tag % :query', query:).order(Arel.sql("similarity(tag, '#{quoted_query}') desc"))
  }

  def serialize
    {
      tag:,
      twitter_username:
    }.to_json
  end

  def twitter_url
    "https://twitter.com/#{twitter_username}" if twitter_username.present?
  end

  def twitter_username
    self[:twitter_username] || TWITTER_USERNAME_FALLBACKS[tag.downcase]
  end

end
