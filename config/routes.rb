Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "home#index"

  resources :account_statements, only: %i[index show new create destroy] do
    resources :transactions, only: :index, module: :account_statements
  end

  resources :credit_card_statements, only: %i[index show new create destroy] do
    resources :transactions, only: :index, module: :credit_card_statements
  end
end
