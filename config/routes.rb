Rails.application.routes.draw do

  root 'application#index'
  get 'past' => 'application#past', as: :past_events

  get 'players/search' => 'players#search'
  get 'players/:player' => 'application#index', as: :player
  get 'players/:player/past' => 'application#past', as: :player_past

  get 'up' => 'rails/health#show', as: :rails_health_check

end
