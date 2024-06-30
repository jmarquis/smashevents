class ApplicationController < ActionController::Base

  def index
    @tournaments = Tournament.where('end_at > ?', Date.today)
  end

end
