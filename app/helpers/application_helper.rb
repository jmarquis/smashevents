module ApplicationHelper

  def date_range(t)
    if t.start_at.day == t.end_at.day
      t.start_at.strftime('%b %-d, %Y')
    elsif t.start_at.month == t.end_at.month
      "#{t.start_at.strftime('%b %-d')} – #{t.end_at.strftime('%-d, %Y')}"
    elsif t.start_at.year == t.end_at.year
      "#{t.start_at.strftime('%b %-d')} – #{t.end_at.strftime('%b %-d, %Y')}"
    else
      "#{t.start_at.strftime('%b %-d, %Y')} – #{t.end_at.strftime('%b %-d, %Y')}"
    end
  end

  def player_count(tournament, melee: true, ultimate: true)
    num = 0
    num += tournament.melee_player_count if melee
    num += tournament.ultimate_player_count if ultimate

    "#{num.round(-1)}+"
  end

end
