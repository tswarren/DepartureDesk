Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  namespace :administration do
    resource :agency, only: %i[show edit update]
    resources :team_members, only: %i[index show] do
      member do
        patch :role
        post :suspend
        post :reactivate
        post :replace_invitation
        post :revoke_invitation
      end
    end
    resources :invitations, only: %i[new create]
  end

  resources :invitation_acceptances, param: :token, only: %i[edit update]

  root "dashboard#show"

  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end
end
