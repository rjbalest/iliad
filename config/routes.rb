Rails.application.routes.draw do

  #resources :performances
  get 'performances/:portfolio_id', to: 'performances#index', as: 'performance'

  resources :transactions
  resources :quotes
  get '/query/:ticker', to: 'quotes#query', defaults: { format: :json }

  resources :positions
  resources :securities

  resources :portfolios do
    member do
     get 'performance'
    end
  end

  root to: 'visitors#index'
  devise_for :users
  resources :users
end
