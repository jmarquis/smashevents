class ApplicationController < ActionController::Base

  def index

    if params[:melee] || params[:ultimate]
      @melee = params[:melee].present?
      @ultimate = params[:ultimate].present?
      cookies[:melee] = @melee
      cookies[:ultimate] = @ultimate
    else
      @melee = true unless ActiveModel::Type::Boolean.new.cast(cookies[:melee]) == false
      @ultimate = true unless ActiveModel::Type::Boolean.new.cast(cookies[:ultimate]) == false
    end

    @tournaments = Tournament.where('end_at > ?', Date.today)

    if !@melee
      @tournaments = @tournaments.where('ultimate_player_count > ?', Tournament::ULTIMATE_THRESHOLD)
    elsif !@ultimate
      @tournamnets = @tournaments.where('melee_player_count > ?', Tournament::MELEE_THRESHOLD)
    end

  end

end
