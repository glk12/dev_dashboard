Rails.application.routes.draw do
  root "my_pull_requests#index"
  
  resources :repositories

  get "my_pull_requests", to: "my_pull_requests#index"

  get "/login", to: "sessions#new", as: :login
  get "/auth/github/callback", to: "sessions#create"
  get "/auth/failure", to: "sessions#failure"
  delete "/logout", to: "sessions#destroy", as: :logout

  get "/settings/github-token", to: "github_credentials#edit", as: :edit_github_token
  patch "/settings/github-token", to: "github_credentials#update", as: :github_token
  delete "/settings/github-token", to: "github_credentials#destroy"

  get "up" => "rails/health#show", as: :rails_health_check
end
