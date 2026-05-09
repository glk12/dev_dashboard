Rails.application.routes.draw do
  root "my_pull_requests#index"
  
  resources :repositories

  get "my_pull_requests", to: "my_pull_requests#index"

  get "up" => "rails/health#show", as: :rails_health_check

end
