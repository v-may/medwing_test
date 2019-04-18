Rails.application.routes.draw do
  resources :thermostats, only: [] do
    member do
      get :stats
    end
    resources :readings, only: [:create]
  end
  resources :readings, only: [:show]
end
