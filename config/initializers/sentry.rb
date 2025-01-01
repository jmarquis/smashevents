# frozen_string_literal: true

Sentry.init do |config|
  config.dsn = 'https://c98ff5cabe96311961b7faad358d400b@o4508150432858112.ingest.us.sentry.io/4508150435676160'
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]
  config.enabled_environments = ['production']

  config.traces_sample_rate = 0.1

  config.profiler_class = Sentry::Vernier::Profiler
  config.profiles_sample_rate = 1.0
end
