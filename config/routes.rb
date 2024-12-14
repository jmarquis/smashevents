Rails.application.routes.draw do

  root 'application#index'
  get 'past' => 'application#past', as: :past_events

  get 'up' => 'rails/health#show', as: :rails_health_check

end
