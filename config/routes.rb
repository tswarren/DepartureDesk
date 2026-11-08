Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  resource :account_password, only: %i[edit update]
  resources :invitation_acceptances, param: :token, only: %i[edit update]
  resource :current_office, only: %i[edit update]
  resource :agency_logo, only: :show

  get "up" => "rails/health#show", as: :rails_health_check

  namespace :administration do
    resource :agency, only: %i[show edit update]
    resource :agency_logo, only: %i[update destroy]
    resource :footer_preview, only: :create
    resource :client_terms_defaults, only: %i[show update]
    resources :cancellation_tiers, only: %i[new create edit update destroy]
    resources :traveler_types, only: %i[create edit update] do
      resource :position, only: :update, controller: "traveler_type_positions"
    end
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
      resource :permissions, only: %i[edit update], controller: "user_permissions"
    end
  end

  resources :clients, only: %i[index new create]
  # S-22 to S-24: travelers, their links to clients, and Client Trips (CLT-02, CLT-05 to CLT-11, OVR-02).
  resources :travelers, only: %i[show new create edit update]
  resources :traveler_links, only: %i[new create destroy]
  resources :client_trips, path: "trips", only: %i[show new create edit update] do
    resources :bookings, only: :create, controller: "client_bookings"
  end
  # S-26: the booking workspace (BKG-05 to BKG-11, BKG-14 to BKG-16, BKG-45, CLT-13, CLT-15, INV-17 to INV-23).
  resources :client_bookings, path: "bookings", only: :show do
    resources :travelers, only: %i[create update destroy], controller: "booking_travelers" do
      resource :move, only: :create, controller: "booking_traveler_moves"
    end
    resource :traveler_batch, only: :create, controller: "booking_traveler_batches"
    resources :selections, only: %i[create update destroy], controller: "choice_selections"
    resource :hold, only: %i[create update destroy], controller: "booking_holds"
    resource :discard, only: :create, controller: "booking_discards"
    resource :confirmation, only: :create, controller: "booking_confirmations"
    # S-27: record acceptance (BKG-39, BKG-41), with its evidence (ADR 0019 amendment).
    resources :acceptances, only: %i[new create], controller: "booking_acceptances" do
      resource :evidence, only: :show, controller: "booking_acceptance_evidence"
    end
    resources :cost_lines, only: :update, controller: "booking_supplier_costs", defaults: { record: "cost_line" }
    resources :commissions, only: :update, controller: "booking_supplier_costs", defaults: { record: "commission" }
  end
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

  resources :client_organizations, path: "clients/organizations", param: :client_organization_id, only: %i[index new create show edit update] do
    member do
      get "status/edit", action: :edit_status
      patch :status, action: :update_status
      post :client, action: :create_client
      get "client/status/edit", action: :edit_client_status
      patch "client/status", action: :update_client_status
    end
  end
  scope "/clients/organizations/:client_organization_id", as: :client_organization do
    resources :contacts, controller: "client_organization_contacts", param: :organization_contact_id, only: %i[index new create show edit update] do
      member do
        get "end", action: :edit_end
        patch :end, action: :end
        patch :primary, action: :primary
      end
    end

    {
      email_addresses: "email-addresses",
      phone_numbers: "phone-numbers",
      postal_addresses: "postal-addresses",
      websites: "websites"
    }.each do |name, path|
      resources name, path: path, param: :contact_point_id, only: %i[new create edit update], controller: "client_organization_#{name}" do
        member do
          get "status/edit", action: :edit_status
          patch :status, action: :update_status
          post :set_primary
        end
      end
    end
  end

  resources :suppliers, param: :supplier_id, only: %i[index new create show edit update] do
    member do
      get "status/edit", action: :edit_status
      patch :status, action: :update_status
      get "categories/edit", action: :edit_categories
      patch :categories, action: :update_categories
    end
  end
  scope "/suppliers/:supplier_id", as: :supplier do
    resources :payee_accounts, controller: "supplier_payee_accounts", only: %i[new create edit update]

    resources :locations, controller: "supplier_locations", param: :supplier_location_id, only: %i[new create show edit update] do
      member do
        get "status/edit", action: :edit_status
        patch :status, action: :update_status
      end
    end

    resources :contacts, controller: "supplier_contacts", param: :supplier_contact_id, only: %i[new create show edit update] do
      member do
        get "status/edit", action: :edit_status
        patch :status, action: :update_status
        patch :preferred
      end
    end

    {
      email_addresses: "email-addresses",
      phone_numbers: "phone-numbers",
      postal_addresses: "postal-addresses",
      websites: "websites"
    }.each do |name, path|
      resources name, path: path, param: :contact_point_id, only: %i[new create edit update], controller: "supplier_#{name}" do
        member do
          get "status/edit", action: :edit_status
          patch :status, action: :update_status
          post :set_primary
        end
      end
    end
  end

  scope "/suppliers/:supplier_id/contacts/:supplier_contact_id", as: :supplier_contact do
    {
      email_addresses: "email-addresses",
      phone_numbers: "phone-numbers"
    }.each do |name, path|
      resources name, path: path, param: :contact_point_id, only: %i[new create edit update], controller: "supplier_contact_#{name}" do
        member do
          get "status/edit", action: :edit_status
          patch :status, action: :update_status
          post :set_primary
        end
      end
    end
  end

  resources :departures, only: %i[index new create show edit update] do
    resource :ready_to_sell, only: %i[show create], controller: "departure_ready_to_sells"
    resources :decisions, only: :create, controller: "departure_decisions"
    resource :inventory, only: :show, controller: "departure_inventories"
    # S-25: the Departure roster (BKG-06).
    resources :bookings, only: %i[index new create], controller: "departure_bookings"
    resources :tasks, only: :index, controller: "departure_tasks"
    resource :supplier_money, only: :show, controller: "departure_supplier_money"
    # S-20 and S-21: the package and its client terms (BKG-13 to BKG-16, BKG-21, BKG-28, BKG-31, CMN-09).
    resources :offerings, only: %i[index new create edit update] do
      resources :choices, only: %i[new create edit update destroy], controller: "offering_choices" do
        resources :options, only: %i[new create edit update destroy], controller: "offering_options"
        resource :prices, only: %i[edit update], controller: "offering_choice_prices"
      end
      resources :prices, only: %i[create destroy], controller: "offering_prices"
    end
    resource :client_terms, only: %i[show create update], controller: "departure_client_terms"
    resource :client_terms_next_version, only: :create, controller: "departure_client_terms_next_versions"
    resources :client_cancellation_tiers, only: %i[new create edit update destroy]
    resources :client_schedule_lines, only: %i[new create edit update destroy]
    resources :arrangements, controller: "supplier_arrangements", only: %i[index new create show edit update] do
      resource :discard, only: :create, controller: "supplier_arrangement_discards"
      resource :confirmation, only: %i[show create], controller: "supplier_arrangement_confirmations"
      resources :documents, only: %i[show create destroy], controller: "arrangement_documents"
      # S-14: the supplier rate grid (SUP-35).
      resource :rates, only: %i[edit update], controller: "supplier_rates"
      resource :rate_pattern, only: :update, controller: "supplier_rate_patterns"
      resources :rate_bands, only: %i[create destroy], controller: "supplier_rate_bands"
      resource :rate_copy, only: :create, controller: "supplier_rate_copies"
      resources :deadlines, only: %i[new create edit update], controller: "supplier_deadlines"
      resources :cost_lines, only: %i[new create edit update destroy]
      resources :schedule_lines, only: %i[new create edit update]
      resources :trigger_events, only: %i[new create]
      resources :amounts_due, only: %i[new create], controller: "direct_amounts_due"
      resources :groups, only: %i[show new create edit update destroy], controller: "inventory_groups" do
        resource :capacity_rule, only: :update, controller: "capacity_rules"
        resources :capacity_events, only: :create, controller: "capacity_events"
      end
    end
    # The team member id in these routes is the agency user's id.
    resources :team_members, only: %i[create destroy], controller: "departure_team_members" do
      collection do
        patch :default_owner
      end
    end
  end
  get "departures/:id/return-to-draft", to: "departure_return_to_drafts#edit", as: :edit_departure_return_to_draft
  post "departures/:id/return-to-draft", to: "departure_return_to_drafts#create", as: :departure_return_to_draft
  get "departures/:id/departed", to: "departure_departeds#new", as: :new_departure_departed
  post "departures/:id/departed", to: "departure_departeds#create", as: :departure_departed

  # S-33 My tasks, and the task lifecycle as verb resources (OPS-03).
  resources :tasks, only: %i[index show] do
    resource :start, only: :create, controller: "task_starts"
    resource :completion, only: :create, controller: "task_completions"
    resource :waiver, only: :create, controller: "task_waivers"
    resource :reopening, only: :create, controller: "task_reopenings"
    resource :assignment, only: :update, controller: "task_assignments"
  end

  root "dashboard#show"

  if Rails.env.development?
    namespace :dev do
      get "ui", to: "ui#show"
    end
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end
end
