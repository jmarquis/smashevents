# frozen_string_literal: true

Rails.logger.info "Initializing Sentry for environment #{Rails.env}"

Sentry.init do |config|
  config.dsn = 'https://28312cd5aa6870d81ebcc66fa1b356d9@o4504436965179392.ingest.us.sentry.io/4511384438374400'
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]
  config.enabled_environments = ['production']

  config.traces_sample_rate = 0.1

  config.profiler_class = Sentry::Vernier::Profiler
  config.profiles_sample_rate = 1.0
end

Rails.logger.info 'Sentry initialized'
