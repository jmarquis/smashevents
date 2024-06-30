# == Schema Information
#
# Table name: tournament_overrides
#
#  id         :bigint           not null, primary key
#  include    :boolean
#  slug       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_tournament_overrides_on_include  (include)
#  index_tournament_overrides_on_slug     (slug) UNIQUE
#
class TournamentOverride < ApplicationRecord
end
