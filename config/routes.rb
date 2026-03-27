Rails.application.routes.draw do
  get "/signup", to: "registrations#new"
  post "/signup", to: "registrations#create"
  get "/login", to: "sessions#new"
  post "/login", to: "sessions#create"
  delete "/logout", to: "sessions#destroy"

  get "reports/profit_loss", to: "reports#profit_loss", as: :reports_profit_loss
  get "support", to: "support#show", as: :support
  get "support/thank_you", to: "support#thank_you", as: :support_thank_you
  resource :company_profile, only: [ :show, :edit, :update ]
  get "customers", to: "customers#index", as: :customers
  resources :tax_payments
  resources :maintenances
  resources :mileages
  resources :fuel_logs
  resources :expenses
  resources :invoices do
    member do
      get :email
      post :send_email
    end
  end
  root "home#index"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
