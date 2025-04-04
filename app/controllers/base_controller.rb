class BaseController < ActionController::Base

  around_action :record_action_metrics

  private

  def record_action_metrics
    StatsD.increment("request.#{controller_name}.#{action_name}")
    StatsD.measure("request.#{controller_name}.#{action_name}") do
      yield
    end
  end

end
