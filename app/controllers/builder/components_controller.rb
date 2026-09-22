# frozen_string_literal: true

module Builder
  class ComponentsController < ApplicationController
    include DepartureAccess
    include CompositionAccess

    before_action :require_builder_access!
    before_action :set_departure
    before_action :set_service_offer, only: %i[
      edit_fulfillment update_fulfillment edit_sources create_source_binding
      edit_cruise_setup update_cruise_setup edit_hotel_setup update_hotel_setup
    ]

    def new
      redirect_to new_departure_composition_service_path(@departure, composition_context_params)
    end

    def create
      redirect_to new_departure_composition_service_path(@departure, composition_context_params)
    end

    def edit_fulfillment
      @version = editable_version!
      assign_return_context
    end

    def update_fulfillment
      version = editable_version!
      assign_return_context
      basis = params[:fulfillment_basis].to_s
      if basis == "undecided" || basis == "decide_later"
        redirect_to focused_return_location, notice: "Left as decide later."
        return
      end
      if basis == "m3_backed" || basis == "supplier_supported"
        redirect_to sources_departure_builder_component_path(
          @departure, @service_offer, focused_context_params
        )
        return
      end

      ResolveServiceOfferFulfillmentBasis.new(
        agency: Current.agency,
        actor: Current.agency_user,
        offer: @service_offer,
        fulfillment_basis: basis,
        version_lock_version: params[:version_lock_version] || version.lock_version
      ).call
      redirect_to focused_return_location, notice: "Fulfillment decided."
    rescue AgencyCommand::Error => error
      raise ActiveRecord::RecordNotFound if error.code == :not_found

      @version = editable_version!
      flash.now[:alert] = error.message
      render :edit_fulfillment, status: :unprocessable_entity
    end

    def edit_sources
      @version = editable_version!
      assign_return_context
      @query = params[:q]
      @search = SearchDepartureOfferSources.call(
        agency: Current.agency, actor: Current.agency_user, departure: @departure, q: @query
      )
      @idempotency_key = SecureRandom.uuid
    rescue AgencyCommand::Error => error
      raise ActiveRecord::RecordNotFound if error.code == :not_found

      @search = SearchDepartureOfferSources::Outcome.new(records: [], truncated: false)
      flash.now[:alert] = error.message
      render :edit_sources, status: :unprocessable_entity
    end

    def create_source_binding
      version = editable_version!
      assign_return_context
      attrs = decode_source_key(
        source_key: params[:source_key],
        membership_kind: params[:membership_kind].presence || "required"
      )
      AddServiceOfferSourceBinding.new(
        agency: Current.agency,
        actor: Current.agency_user,
        offer: @service_offer,
        version_lock_version: params[:version_lock_version] || version.lock_version,
        idempotency_key: params[:idempotency_key].presence || SecureRandom.uuid,
        attributes: attrs
      ).call
      redirect_to focused_return_location, notice: "Supplier support connected to this component."
    rescue AgencyCommand::Error => error
      raise ActiveRecord::RecordNotFound if error.code == :not_found

      @version = editable_version!
      @query = params[:q]
      @search = SearchDepartureOfferSources.call(
        agency: Current.agency, actor: Current.agency_user, departure: @departure, q: @query
      )
      @idempotency_key = params[:idempotency_key].presence || SecureRandom.uuid
      flash.now[:alert] = error.message
      render :edit_sources, status: :unprocessable_entity
    end

    def edit_cruise_setup
      @version = editable_version!
      assign_return_context
      @option_names = existing_option_names.presence || [ "", "" ]
    end

    def update_cruise_setup
      apply_category_helper!(SetupCruiseCabinChoices, "Cabin category")
    end

    def edit_hotel_setup
      @version = editable_version!
      assign_return_context
      @option_names = existing_option_names.presence || [ "", "" ]
    end

    def update_hotel_setup
      apply_category_helper!(SetupHotelRoomChoices, "Room category")
    end

    private

    def require_builder_access!
      raise ActiveRecord::RecordNotFound unless Current.agency_user&.permitted?(:manage_departures)
    end

    def assign_return_context
      @outcome = composition_outcome
      @package_id = begin
        validated_composition_package_id
      rescue ActiveRecord::RecordNotFound
        nil
      end
      @return_to = composition_return_to || "services"
    end

    def focused_context_params
      {
        return_to: @return_to || composition_return_to || "services",
        outcome: @outcome || composition_outcome,
        package_id: @package_id
      }.compact
    end

    def focused_return_location
      assign_return_context if @return_to.blank?
      composition_path_for_return(@return_to)
    end

    def set_service_offer
      @service_offer = @departure.service_offers.find(params[:id])
    end

    def editable_version!
      version = @service_offer.editable_draft_version
      raise ActiveRecord::RecordNotFound if version.nil?

      version
    end

    def existing_option_names
      editable_version!.choice_groups.order(:position).flat_map do |group|
        group.service_offer_choice_options.order(:position).map(&:name)
      end
    end

    def apply_category_helper!(klass, group_name)
      assign_return_context
      version = editable_version!
      names = Array(params[:option_names]).map { |name| name.to_s.strip }.reject(&:blank?)
      if names.empty?
        flash.now[:alert] = "Enter at least one category name."
        @version = version
        @option_names = Array(params[:option_names]).presence || [ "", "" ]
        render action_name.start_with?("update_cruise") ? :edit_cruise_setup : :edit_hotel_setup,
          status: :unprocessable_entity
        return
      end

      if version.choice_groups.exists? && params[:confirm_replace] != "1"
        flash.now[:alert] = "Confirm replacing existing choices before saving."
        @version = version
        @option_names = names
        @require_replace_confirm = true
        render action_name.start_with?("update_cruise") ? :edit_cruise_setup : :edit_hotel_setup,
          status: :unprocessable_entity
        return
      end

      klass.new(
        agency: Current.agency,
        actor: Current.agency_user,
        offer: @service_offer,
        version_lock_version: params[:version_lock_version] || version.lock_version,
        option_names: names
      ).call
      redirect_to focused_return_location, notice: "#{group_name} categories saved."
    rescue AgencyCommand::Error => error
      raise ActiveRecord::RecordNotFound if error.code == :not_found

      @version = editable_version!
      @option_names = Array(params[:option_names])
      flash.now[:alert] = error.message
      render action_name.start_with?("update_cruise") ? :edit_cruise_setup : :edit_hotel_setup,
        status: :unprocessable_entity
    end

    def decode_source_key(source_key:, membership_kind: "required")
      attrs = { source_key: source_key, membership_kind: membership_kind }.with_indifferent_access
      key = source_key.to_s
      return attrs if key.blank?

      arrangement_id, version_id, item_id, occurrence_id, resource_id, pool_id, tentative = key.split(":")
      attrs.merge(
        supplier_arrangement_id: arrangement_id.presence,
        supplier_arrangement_version_id: version_id.presence,
        arrangement_item_id: item_id.presence,
        service_occurrence_id: occurrence_id.presence,
        supplier_resource_id: resource_id.presence,
        capacity_pool_id: pool_id.presence,
        use_tentative_draft: tentative == "1"
      )
    end
  end
end
