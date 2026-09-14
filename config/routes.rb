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

  resources :clients, only: %i[index new create]
  resources :client_people, path: "clients/people", param: :client_person_id, only: %i[new create show edit update] do
    member do
      get "status/edit", action: :edit_status
      patch :status, action: :update_status
      post :client, action: :create_client
      get "client/status/edit", action: :edit_client_status
      patch "client/status", action: :update_client_status
    end
  end
  scope "/clients/people/:client_person_id", as: :client_person do
    {
      email_addresses: "email-addresses",
      phone_numbers: "phone-numbers",
      postal_addresses: "postal-addresses"
    }.each do |name, path|
      resources name, path: path, param: :contact_point_id, only: %i[new create edit update], controller: "client_person_#{name}" do
        member do
          get "status/edit", action: :edit_status
          patch :status, action: :update_status
          post :set_primary
        end
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
