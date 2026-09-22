# frozen_string_literal: true

module Builder
  class ComponentsController < ApplicationController
    include DepartureAccess

    before_action :require_builder_access!
    before_action :set_departure
    before_action :set_service_offer, only: %i[
      edit_fulfillment update_fulfillment edit_sources create_source_binding
      edit_cruise_setup update_cruise_setup edit_hotel_setup update_hotel_setup
    ]

    def new
      @package_decision = params[:package_decision].presence || "yes"
      @component = component_defaults
      @selected_package = resolve_package_for_form
      @idempotency_key = SecureRandom.uuid
    end

    def create
      @idempotency_key = params[:idempotency_key].presence || SecureRandom.uuid
      @package_decision = params[:package_decision].to_s
      @component = component_params.to_h
      @selected_package = resolve_package_for_form
      @return_intent = params[:return_intent].to_s

      package_id = @selected_package&.id
      if first_component? && @package_decision == "yes"
        result = CreateInitialPackageWithOutlineServiceOffer.new(
          agency: Current.agency,
          actor: Current.agency_user,
          departure: @departure,
          idempotency_key: @idempotency_key,
          attributes: {
            package_name: params[:package_name].presence || @departure.name,
            component_name: @component[:name],
            client_title: @component[:name],
            client_timing_text: @component[:client_timing_text],
            placement: params[:placement].presence || "included"
          }
        ).call
        package = result.is_a?(AgencyCommand::Result) ? result.record : result
        package_id = package&.id
      elsif @selected_package.present? && !first_component?
        version = @selected_package.editable_draft_version
        raise ActiveRecord::RecordNotFound if version.nil?

        CreatePackageInlineServiceOffer.new(
          agency: Current.agency,
          actor: Current.agency_user,
          package: @selected_package,
          version_lock_version: params[:version_lock_version] || version.lock_version,
          idempotency_key: @idempotency_key,
          attributes: {
            name: @component[:name],
            client_title: @component[:name],
            client_timing_text: @component[:client_timing_text],
            placement: params[:placement].presence || "included",
            fulfillment_basis: "undecided"
          }
        ).call
      else
        CreateServiceOfferOutline.new(
          agency: Current.agency,
          actor: Current.agency_user,
          departure: @departure,
          idempotency_key: @idempotency_key,
          attributes: {
            name: @component[:name],
            client_title: @component[:name],
            client_timing_text: @component[:client_timing_text]
          }
        ).call
      end

      if @return_intent == "add_another"
        redirect_to new_departure_builder_component_path(@departure, package_id: package_id),
          notice: "Component saved."
      else
        redirect_to departure_builder_path(@departure, package_id: package_id),
          notice: "Component saved."
      end
    rescue AgencyCommand::Error => error
      raise ActiveRecord::RecordNotFound if error.code == :not_found

      @component_error = error.message
      flash.now[:alert] = error.message
      render :new, status: :unprocessable_entity
    end

    def edit_fulfillment
      @version = editable_version!
    end

    def update_fulfillment
      version = editable_version!
      basis = params[:fulfillment_basis].to_s
      if basis == "undecided" || basis == "decide_later"
        redirect_to departure_builder_path(@departure, work_on: "supplier"), notice: "Left as decide later."
        return
      end
      if basis == "m3_backed" || basis == "supplier_supported"
        redirect_to sources_departure_builder_component_path(@departure, @service_offer)
        return
      end

      ResolveServiceOfferFulfillmentBasis.new(
        agency: Current.agency,
        actor: Current.agency_user,
        offer: @service_offer,
        fulfillment_basis: basis,
        version_lock_version: params[:version_lock_version] || version.lock_version
      ).call
      redirect_to departure_builder_path(@departure, work_on: "supplier"), notice: "Fulfillment decided."
    rescue AgencyCommand::Error => error
      raise ActiveRecord::RecordNotFound if error.code == :not_found

      @version = editable_version!
      flash.now[:alert] = error.message
      render :edit_fulfillment, status: :unprocessable_entity
    end

    def edit_sources
      @version = editable_version!
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
      redirect_to departure_builder_path(@departure, work_on: "supplier"),
        notice: "Supplier support connected to this component."
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
      @option_names = existing_option_names.presence || [ "", "" ]
    end

    def update_cruise_setup
      apply_category_helper!(SetupCruiseCabinChoices, "Cabin category")
    end

    def edit_hotel_setup
      @version = editable_version!
      @option_names = existing_option_names.presence || [ "", "" ]
    end

    def update_hotel_setup
      apply_category_helper!(SetupHotelRoomChoices, "Room category")
    end

    private

    def require_builder_access!
      raise ActiveRecord::RecordNotFound unless Current.agency_user&.permitted?(:manage_departures)
    end

    def first_component?
      @departure.service_offers.none? && @departure.packages.none?
    end

    def component_defaults
      { name: params[:name], client_timing_text: params[:client_timing_text] }
    end

    def component_params
      params.permit(:name, :client_timing_text)
    end

    def resolve_package_for_form
      id = params[:package_id].presence
      return if id.blank?

      @departure.packages.find_by(id: id)
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
      redirect_to departure_builder_path(@departure), notice: "#{group_name} categories saved."
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
