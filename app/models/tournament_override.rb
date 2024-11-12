# == Schema Information
#
# Table name: tournament_overrides
#
#  id         :integer          not null, primary key
#  slug       :string
#  include    :boolean
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
