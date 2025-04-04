Rails.application.configure do
  config.lograge.enabled = true
  config.lograge.ignore_actions = ['ApplicationController#ping']
  config.lograge.custom_options = lambda do |event|
    {
      time: Time.now.utc
    }
  end
end
