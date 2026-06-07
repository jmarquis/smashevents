class PlayersController < BaseController

  def search
    return render json: { success: false } if params[:q].blank?

    render json: {
      success: true,
      results: Player.tag_similar_to(params[:q]).limit(10).pluck(:tag).uniq
    }
  end

end
