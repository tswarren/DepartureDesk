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
    resource :composition, only: :show, controller: "departure_compositions" do
      get :services
      get :suppliers
      get :package
      get :review
      resources :services, only: %i[new create], controller: "composition_services"
      namespace :suppliers do
        resources :cruises, only: %i[new create], controller: "/composition_cruises"
        resources :hotels, only: %i[new create], controller: "/composition_hotels"
        resources :transportations, only: %i[new create], controller: "/composition_transportations"
        resources :activities, only: %i[new create], controller: "/composition_activities"
      end
    end
    resource :builder, only: %i[show], controller: "departure_builders"
    namespace :builder do
      resources :components, only: %i[new create] do
        member do
          get :fulfillment, action: :edit_fulfillment
          post :fulfillment, action: :update_fulfillment
          get :sources, action: :edit_sources
          post :sources, action: :create_source_binding
          get :cruise_setup, action: :edit_cruise_setup
          post :cruise_setup, action: :update_cruise_setup
          get :hotel_setup, action: :edit_hotel_setup
          post :hotel_setup, action: :update_hotel_setup
        end
      end
      resources :packages, only: [] do
        resource :inclusions_reorder, only: %i[show update], controller: "inclusion_reorders"
      end
    end
    resources :service_offer_outlines, only: %i[create], controller: "service_offer_outlines"
    resource :initial_package_outline, only: %i[create], controller: "initial_package_outlines"
    resources :arrangements, controller: "supplier_arrangements", only: %i[index new create show edit update] do
      collection do
        get :search
      end
      resource :cruise, only: :show, controller: "cruise_arrangements" do
        post :successor
        resource :activation, only: %i[show create], controller: "cruise_activations"
        resource :inventory_change, only: :show, controller: "cruise_inventory_changes" do
          get :same_terms
          post :same_terms, action: :create_same_terms
          get :changed_terms
          post :changed_terms, action: :create_changed_terms
        end
        resource :active_version, only: :show, controller: "cruise_active_versions"
        resource :agreement, only: :show, controller: "cruise_agreements" do
          post :provisional
          post :confirm
          post :correct
          post :terms
        end
        resource :sailing, only: %i[edit update], controller: "cruise_sailings"
        resources :commercial_benefits, only: %i[create update],
          param: :term_type, controller: "cruise_commercial_benefits"
        resource :supplier_rates, only: :show, controller: "cruise_supplier_rate_summaries"
        resources :cabin_categories, path: "cabin-categories",
          param: :resource_id, only: %i[index new create edit update destroy],
          controller: "cruise_cabin_categories" do
          resource :supplier_rates, path: "supplier-rates", only: %i[show create update],
            controller: "cruise_supplier_rates" do
            put :occupancy_plan
            post :forecast_readiness
            post :preview
            post :record_contracted
          end
        end
        resource :service_connection, path: "service-connection", only: %i[show create update],
          controller: "cruise_service_connections"
        resource :client_terms, path: "client-terms", only: %i[show create update destroy],
          controller: "cruise_client_terms" do
          match :preview, via: %i[post patch]
        end
        resource :deposits_and_deadlines, path: "deposits-and-deadlines", only: :show,
          controller: "cruise_deposits_and_deadlines" do
          resources :deadlines, only: %i[create update destroy],
            controller: "cruise_supplier_deadlines"
          resources :deposits, only: %i[create update destroy],
            controller: "cruise_supplier_deposits"
          post "deposit-preview", to: "cruise_supplier_deposits#preview", as: :deposit_preview
          post "activation-preview", to: "cruise_deposits_and_deadlines#activation_preview",
            as: :activation_preview
        end
      end
      resource :hotel, only: :show, controller: "hotel_arrangements" do
        resources :stays, only: %i[new create], controller: "hotel_stays"
        get "items/:item_id/stay/edit", to: "hotel_stays#edit", as: :edit_item_stay
        patch "items/:item_id/stay", to: "hotel_stays#update", as: :item_stay
        get "items/:item_id/inventory", to: "hotel_room_inventories#show", as: :item_inventory
        patch "items/:item_id/inventory", to: "hotel_room_inventories#update"
        get "items/:item_id/rates", to: "hotel_supplier_rates#show", as: :item_rates
        patch "items/:item_id/rates", to: "hotel_supplier_rates#update"
        post "items/:item_id/inventory/resources", to: "hotel_room_inventories#create_resource", as: :item_inventory_resources
        patch "items/:item_id/inventory/resources/:resource_id", to: "hotel_room_inventories#update_resource", as: :item_inventory_resource
        get "items/:item_id/hotel_agreement", to: "hotel_agreements#show", as: :item_hotel_agreement
        get "items/:item_id/hotel_review", to: "hotel_reviews#show", as: :item_hotel_review
        post "items/:item_id/hotel_review/confirmation", to: "hotel_reviews#confirm", as: :item_hotel_review_confirmation
        post "items/:item_id/hotel_review/revision", to: "hotel_reviews#revise", as: :item_hotel_review_revision
        post "items/:item_id/hotel_review/activation", to: "hotel_reviews#activate", as: :item_hotel_review_activation
        post "items/:item_id/hotel_agreement/terms/:kind/absence", to: "hotel_agreement_terms#record_absence", as: :item_hotel_agreement_term_absence
        delete "items/:item_id/hotel_agreement/absences/:id", to: "hotel_agreement_terms#destroy_absence", as: :item_hotel_agreement_absence
        get "items/:item_id/hotel_agreement/deposits/new", to: "hotel_agreement_deposits#new", as: :new_item_hotel_agreement_deposit
        post "items/:item_id/hotel_agreement/deposits", to: "hotel_agreement_deposits#create", as: :item_hotel_agreement_deposits
        get "items/:item_id/hotel_agreement/deposits/:id/edit", to: "hotel_agreement_deposits#edit", as: :edit_item_hotel_agreement_deposit
        patch "items/:item_id/hotel_agreement/deposits/:id", to: "hotel_agreement_deposits#update", as: :item_hotel_agreement_deposit
        delete "items/:item_id/hotel_agreement/deposits/:id", to: "hotel_agreement_deposits#destroy"
        get "items/:item_id/hotel_agreement/deadlines/new", to: "hotel_agreement_deadlines#new", as: :new_item_hotel_agreement_deadline
        post "items/:item_id/hotel_agreement/deadlines", to: "hotel_agreement_deadlines#create", as: :item_hotel_agreement_deadlines
        get "items/:item_id/hotel_agreement/deadlines/:id/edit", to: "hotel_agreement_deadlines#edit", as: :edit_item_hotel_agreement_deadline
        patch "items/:item_id/hotel_agreement/deadlines/:id", to: "hotel_agreement_deadlines#update", as: :item_hotel_agreement_deadline
        delete "items/:item_id/hotel_agreement/deadlines/:id", to: "hotel_agreement_deadlines#destroy"
        get "items/:item_id/hotel_agreement/terms/:kind/new", to: "hotel_agreement_terms#new", as: :new_item_hotel_agreement_term
        post "items/:item_id/hotel_agreement/terms/:kind", to: "hotel_agreement_terms#create", as: :item_hotel_agreement_terms
        get "items/:item_id/hotel_agreement/terms/:id/edit", to: "hotel_agreement_terms#edit", as: :edit_item_hotel_agreement_term
        patch "items/:item_id/hotel_agreement/terms/:id", to: "hotel_agreement_terms#update", as: :item_hotel_agreement_term
        delete "items/:item_id/hotel_agreement/terms/:id", to: "hotel_agreement_terms#destroy"
      end
      resource :activity, only: :show, controller: "activity_arrangements" do
        resources :items, only: %i[create update], controller: "activity_items"
        resource :confirmation, only: :create, controller: "activity_confirmations"
        resource :activation, only: :create, controller: "activity_activations"
        resource :outcome, only: :create, controller: "activity_outcomes"
        resource :successor, only: :create, controller: "activity_successors"
        resource :revision, only: :create, controller: "activity_revisions"
        resource :final_count, only: :create, controller: "activity_final_counts"
      end
      resource :transportation, only: :show, controller: "transportation_arrangements" do
        resources :segments, only: %i[new create edit update], controller: "transportation_segments"
        resource :confirmation, only: :create, controller: "transportation_confirmations"
        resource :activation, only: :create, controller: "transportation_activations"
        resource :amount_due, only: :create, controller: "transportation_amount_dues"
        resource :coach_change, only: :create, controller: "transportation_coach_changes"
        resource :successor, only: :create, controller: "transportation_successors"
        resource :revision, only: :create, controller: "transportation_revisions"
        resource :final_count, only: :create, controller: "transportation_final_counts"
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
