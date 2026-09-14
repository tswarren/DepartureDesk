Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  resource :account_password, only: %i[edit update]
  resources :invitation_acceptances, param: :token, only: %i[edit update]
  resource :current_office, only: %i[edit update]

  get "up" => "rails/health#show", as: :rails_health_check

  namespace :administration do
    resource :agency, only: %i[show edit update]
    resources :offices, only: %i[index show new create edit update] do
      member do
        post :deactivate
        post :reactivate
      end
    end
    resources :agency_users, only: %i[index show new create edit update] do
      member do
        post :suspend
        post :reactivate
        post :close
        post :replace_invitation
        post :revoke_invitation
      end
    end
  end

  root "dashboard#show"

  if Rails.env.development?
    namespace :dev do
      get "ui", to: "ui#show"
    end
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end
end
