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
    resources :offices, only: %i[index show new create edit update] do
      member do
        post :deactivate
        post :reactivate
      end
    end
    resources :team_members, only: %i[index show] do
      member do
        patch :role
        post :suspend
        post :reactivate
        post :replace_invitation
        post :revoke_invitation
        post :grant_office
        post :revoke_office
        post :set_default_office
      end
    end
    resources :invitations, only: %i[new create]
  end

  resource :current_office, only: %i[edit update]

  resources :invitation_acceptances, param: :token, only: %i[edit update]

  root "dashboard#show"

  namespace :directory do
    resources :parties, only: %i[index new create show edit update] do
      resources :alternate_names, only: %i[create update destroy]
      resource :contact_information, only: :show, controller: "contact_information"
      resource :relationships, only: :show, controller: "relationships"
      resource :notes, only: :show, controller: "notes"
      resources :contact_points, only: %i[new create edit update] do
        member do
          post :deactivate
          post :reactivate
          post :suppress
          post :unsuppress
          post :set_primary
        end
        resources :purposes, only: %i[new create], controller: "contact_point_purposes" do
          member do
            post :end, action: :close
            post :correct
          end
        end
      end
      resources :party_relationships, only: %i[new create], path: "related_parties" do
        member do
          post :end, action: :close
          post :correct
          post :void
        end
        resources :purposes, only: %i[new create], controller: "relationship_purposes" do
          member do
            post :end, action: :close
            post :correct
          end
        end
      end
      resources :party_notes, only: :create do
        member do
          post :correct
          post :remove
          post :pin
          post :unpin
        end
      end
    end
  end

  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end
end
