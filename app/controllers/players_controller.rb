class PlayersController < ActionController::Base

  def search
    if params[:q].blank?
      return render json: { success: false }
    end

    return render json: {
      success: true,
      results: Player.tag_similar_to(params[:q]).limit(10).pluck(:tag).uniq
    }
  end

end
