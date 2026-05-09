# frozen_string_literal: true

Sentry.init do |config|
  config.dsn = 'https://718bfad1c4be69e9f4fce5ba8ad74e33@o4511362620391424.ingest.us.sentry.io/4511362622095360'
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]
  config.enabled_environments = ['production']

  config.traces_sample_rate = 0.1

  config.profiler_class = Sentry::Vernier::Profiler
  config.profiles_sample_rate = 1.0
end
