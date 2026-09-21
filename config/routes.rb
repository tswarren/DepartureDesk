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
    member do
      post :activate
    end
    resource :responsibility, only: %i[edit update], controller: "departure_responsibilities"
    resource :activation, only: :show, controller: "departure_activations"
    resources :service_offer_outlines, only: %i[create], controller: "service_offer_outlines"
    resource :initial_package_outline, only: %i[create], controller: "initial_package_outlines"
    resources :arrangements, controller: "supplier_arrangements", only: %i[index new create show edit update] do
      collection do
        get :search
      end
      resource :activation,
        only: %i[show create],
        controller: "supplier_arrangement_activations"
      resources :reservations, controller: "supplier_reservations", only: %i[index new create show edit update] do
        collection do
          get :new_existing
          post :record_existing
        end
        member do
          get :abandon, action: :edit_abandon
          post :abandon
          post :request_booking
          post :withdraw
          post :respond
          post :cancel_scopes
          post :revise
        end
      end
      resources :commitments, controller: "supplier_commitments", only: %i[index] do
        collection do
          get :dispose, action: :new_dispose
          post :dispose
          get :waive, action: :new_waive
          post :waive
        end
        member do
          get :reopen, action: :new_reopen
          post :reopen
          get :disqualify, action: :new_disqualify
          post :disqualify
        end
      end
      resource :exposure, controller: "supplier_exposures", only: %i[show] do
        post :rebuild
        post :qualify
      end
      resources :evidence_coverages, controller: "supplier_commitment_evidence_coverages", only: [] do
        member do
          get :revoke, action: :new_revoke
          post :revoke
        end
      end
      member do
        post :successor
        get :abandon, action: :edit_abandon
        post :abandon
        get :end, to: "supplier_arrangement_endings#show"
        post :end, to: "supplier_arrangement_endings#create"
      end
      get "capacity-pools/:pool_id", to: "effective_capacity_pools#show", as: :capacity_pool
      post "capacity-pools/:pool_id/events", to: "capacity_events#create", as: :capacity_pool_events
      post "capacity-pools/:pool_id/reconciliations", to: "capacity_reconciliations#create",
        as: :capacity_pool_reconciliations
      post "capacity-pools/:pool_id/rebuild", to: "capacity_projection_repairs#create",
        as: :capacity_pool_rebuild
      get "items/setup", to: "arrangement_item_setups#new", as: :new_item_setup
      post "items/setup", to: "arrangement_item_setups#create", as: :item_setup
      resources :versions, only: [] do
        resources :commitment_triggers,
          path: "commitment-triggers",
          controller: "supplier_commitment_trigger_definitions",
          only: %i[index new create edit update destroy]
        resources :deadlines,
          path: "deadlines",
          controller: "supplier_deadline_definitions",
          only: %i[index new create edit update destroy]
        resources :deposits,
          path: "deposits",
          controller: "supplier_deposit_requirement_definitions",
          only: %i[index new create edit update destroy]
      end
      post "deposit_commitments/:commitment_id/attest",
        to: "supplier_deposit_operations#attest",
        as: :deposit_attest
      post "planning_milestones",
        to: "supplier_deposit_operations#record_milestone",
        as: :planning_milestones
      resources :items, controller: "arrangement_items", only: %i[new create edit update destroy] do
        collection { patch :reorder }
        patch "capacity/pairs/bulk", to: "bulk_capacity_pairs#update", as: :bulk_capacity_pairs
        post "capacity/pairs/:occurrence_id/:resource_id/pool-setup",
          to: "capacity_pair_pool_setups#create", as: :capacity_pair_pool_setup
        get "costs/setup", to: "supplier_cost_setups#new", as: :new_cost_setup
        post "costs/setup", to: "supplier_cost_setups#create", as: :cost_setup
        get "costs/:source_id/definitions/:id/review",
          to: "supplier_cost_definition_reviews#show", as: :cost_definition_review
        get "costs/workspace", to: "item_costs#show", as: :costs_workspace
        resources :costs, controller: "supplier_cost_sources", only: %i[create update destroy] do
          collection { patch :reorder }
          resources :definitions, controller: "supplier_cost_definitions", only: %i[create update destroy] do
            member do
              post "forecast-ready", action: :forecast_ready, as: :forecast_ready
            end
            resources :components, controller: "supplier_cost_components", only: %i[create update destroy] do
              collection { patch :reorder }
            end
          end
        end
        resources :participant_categories, path: "participant-categories",
          controller: "supplier_cost_participant_categories", only: %i[create update destroy] do
          collection { patch :reorder }
        end
        resources :cost_assumptions, path: "cost-assumptions",
          controller: "supplier_cost_usage_assumptions", only: %i[create update destroy] do
          resources :occupancy_profiles, path: "occupancy-profiles",
            controller: "supplier_cost_occupancy_profiles", only: %i[create update destroy] do
            collection { patch :reorder }
          end
        end
        resource :capacity, controller: "item_capacities", only: %i[show update] do
          # Pool routes use a static "pools" segment and must stay ahead of the
          # occurrence/resource classify routes, which share the same depth.
          uuid = /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/i
          get "pairs/:pair_id/pools/new", to: "capacity_pools#new", as: :new_pair_pool, constraints: { pair_id: uuid }
          post "pairs/:pair_id/pools", to: "capacity_pools#create", as: :pair_pools, constraints: { pair_id: uuid }
          patch "pairs/:pair_id/pools/reorder", to: "capacity_pools#reorder", as: :reorder_pair_pools, constraints: { pair_id: uuid }
          get "pairs/:pair_id/pools/:id/edit", to: "capacity_pools#edit", as: :edit_pair_pool, constraints: { pair_id: uuid, id: uuid }
          patch "pairs/:pair_id/pools/:id", to: "capacity_pools#update", as: :pair_pool, constraints: { pair_id: uuid, id: uuid }
          delete "pairs/:pair_id/pools/:id", to: "capacity_pools#destroy", constraints: { pair_id: uuid, id: uuid }
          post "pairs/:occurrence_id/:resource_id", to: "capacity_pairs#create", as: :pair,
            constraints: { occurrence_id: uuid, resource_id: uuid }
          patch "pairs/:occurrence_id/:resource_id", to: "capacity_pairs#update",
            constraints: { occurrence_id: uuid, resource_id: uuid }
          delete "pairs/:pair_id", to: "capacity_pairs#destroy", as: :defined_pair, constraints: { pair_id: uuid }
        end
        resources :occurrences, controller: "service_occurrences", only: %i[new create edit update destroy]
        resources :resources, controller: "supplier_resources", only: %i[new create edit update destroy] do
          collection { patch :reorder }
        end
      end
      get "costs/setup", to: "supplier_cost_setups#new", as: :new_cost_setup
      post "costs/setup", to: "supplier_cost_setups#create", as: :cost_setup
      get "costs/:source_id/definitions/:id/review",
        to: "supplier_cost_definition_reviews#show", as: :cost_definition_review
      get "costs/workspace", to: "arrangement_costs#show", as: :costs_workspace
      resources :costs, controller: "supplier_cost_sources", only: %i[create update destroy] do
        collection { patch :reorder }
        resources :definitions, controller: "supplier_cost_definitions", only: %i[create update destroy] do
          member do
            post "forecast-ready", action: :forecast_ready, as: :forecast_ready
          end
          resources :components, controller: "supplier_cost_components", only: %i[create update destroy] do
            collection { patch :reorder }
          end
        end
      end
      get "cost-forecast", to: "supplier_cost_forecasts#show", as: :cost_forecast
    end
    resources :service_offers, only: %i[index show new create edit update] do
      collection do
        get :from_source, action: :new_from_source
        post :from_source, action: :create_from_source
        get :sources
      end
      member do
        get :discard, action: :edit_discard
        post :discard
        post :publish
        post :pause_sales
        post :resume_sales
        post :retire
        post :successor
        post :resolve_fulfillment
        post :setup_cruise_cabins
        post :setup_hotel_rooms
      end
      resources :source_bindings, controller: "service_offer_source_bindings", only: %i[new create destroy]
      resource :price, controller: "service_offer_prices", only: %i[create update destroy] do
        post :preview
      end
      resource :choices, controller: "service_offer_choices", only: %i[update]
      resource :terms, controller: "service_offer_terms", only: %i[update]
    end
    resources :packages, only: %i[index show new create edit update] do
      member do
        post :abandon
        post :inline
        post :adopt
        post :include_published
        post :preview
        post :publish
        post :pause_sales
        post :resume_sales
        post :retire
        post :successor
      end
      resources :inclusions, only: [], controller: "package_inclusions" do
        collection { patch :reorder }
      end
      resource :price, controller: "package_prices", only: %i[create update destroy]
      resource :terms, controller: "package_terms", only: %i[update]
    end
  end
  get "departures/:id/return-to-draft", to: "departure_return_to_drafts#edit", as: :edit_departure_return_to_draft
  post "departures/:id/return-to-draft", to: "departure_return_to_drafts#create", as: :departure_return_to_draft
  get "departures/:id/departed", to: "departure_departeds#new", as: :new_departure_departed
  post "departures/:id/departed", to: "departure_departeds#create", as: :departure_departed
  get "departures/:id/schedule/correction", to: "departure_schedule_corrections#edit", as: :edit_departure_schedule_correction
  post "departures/:id/schedule/correction", to: "departure_schedule_corrections#create", as: :departure_schedule_correction
  get "departures/:id/currency/correction", to: "departure_currency_corrections#edit", as: :edit_departure_currency_correction
  post "departures/:id/currency/correction", to: "departure_currency_corrections#create", as: :departure_currency_correction
  get "departures/:id/lifecycle/correction", to: "departure_lifecycle_corrections#edit", as: :edit_departure_lifecycle_correction
  post "departures/:id/lifecycle/correction", to: "departure_lifecycle_corrections#create", as: :departure_lifecycle_correction

  root "dashboard#show"

  if Rails.env.development?
    namespace :dev do
      get "ui", to: "ui#show"
    end
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end
end
