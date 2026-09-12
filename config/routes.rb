Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "home#index"

  resources :accounts, only: %i[index show] do
    resources :transactions, only: :index, module: :accounts
  end

  resources :account_statements, only: %i[index show new create destroy] do
    resources :transactions, only: :index, module: :account_statements
  end

  resources :credit_card_accounts, only: %i[index show] do
    resources :transactions, only: :index, module: :credit_card_accounts
  end

  resources :credit_card_statements, only: %i[index show new create destroy] do
    resources :transactions, only: :index, module: :credit_card_statements
  end

  resources :monthly_credit_card_statements, only: %i[index show new create destroy] do
    resources :unreconciled_transactions, only: %i[index update], module: :monthly_credit_card_statements
    resource :auto_reconcile, only: :create, module: :monthly_credit_card_statements
    resource :save_reconciled, only: :create, module: :monthly_credit_card_statements
  end
end


