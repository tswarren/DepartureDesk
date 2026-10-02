# frozen_string_literal: true

module HotelArrangementAccess
  extend ActiveSupport::Concern

  include SupplierArrangementAccess
  include HotelCompositionContext

  included do
    helper_method :hotel_editor_options, :hotel_agreement_path_for, :hotel_agreement_return?
  end

  private

  def set_hotel_version
    version = @supplier_arrangement.editable_version
    raise ActiveRecord::RecordNotFound if version.nil?

    pin_authorized_version!(@supplier_arrangement, version)
  end

  def set_hotel_agreement_version
    version = if params[:version_id].present?
      @supplier_arrangement.versions.find(params[:version_id])
    else
      @supplier_arrangement.editable_version
    end
    raise ActiveRecord::RecordNotFound if version.nil?

    pin_authorized_version!(@supplier_arrangement, version)
  end

  def pin_authorized_version!(arrangement, version)
    @supplier_arrangement = arrangement
    @authorized_hotel_version_id = version.id
    @supplier_arrangement_version = version
  end

  def set_hotel_item
    @arrangement_item = @supplier_arrangement.arrangement_items.find(params[:item_id])
    @arrangement_item_definition = @supplier_arrangement_version.arrangement_item_definitions.find_by!(
      arrangement_item: @arrangement_item
    )
  end

  def set_lodging_hotel_item
    set_hotel_item
    raise ActiveRecord::RecordNotFound unless @arrangement_item_definition.category == "lodging"
  end

  def hotel_agreement_path_for(item = @arrangement_item, version = @supplier_arrangement_version)
    item_hotel_agreement_departure_arrangement_hotel_path(
      @departure, @supplier_arrangement, item, version_id: version.id
    )
  end

  def hotel_agreement_return?
    params[:return_to] == "hotel_agreement"
  end

  def hotel_editor_options
    hotel_agreement_return? || @hotel_agreement_page ? { return_to: "hotel_agreement" } : {}
  end

  def path_after_hotel_edit(default_path)
    return default_path unless hotel_agreement_return? && @arrangement_item

    item_hotel_agreement_departure_arrangement_hotel_path(
      @departure, @supplier_arrangement, @arrangement_item
    )
  end

  def assign_hotel_shape
    reset_hotel_graph!
    @shape = DetectHotelInventoryShape.new(
      agency: Current.agency,
      arrangement: @supplier_arrangement,
      version: @supplier_arrangement_version,
      item: @arrangement_item
    ).call
  end

  def reset_hotel_graph!
    %i[
      arrangement_item_definitions
      service_occurrence_definitions
      supplier_resource_definitions
      capacity_pool_definitions
      capacity_pair_definitions
    ].each do |name|
      @supplier_arrangement_version.association(name).reset
    end
  end

  def hotel_editable?
    @supplier_arrangement_version.draft? && Current.agency_user.permitted?(:manage_departures)
  end

  def reload_authorized_version!(arrangement = @supplier_arrangement)
    raise ActiveRecord::RecordNotFound if @authorized_hotel_version_id.blank?

    @supplier_arrangement_version = arrangement.versions.find(@authorized_hotel_version_id)
    @supplier_arrangement_version.reload
  end

  def hotel_command_context
    { agency: Current.agency, actor: Current.agency_user }
  end

  def save_new_hotel_stay!(departure:, arrangement:, item_name:, occurrence_attributes:, idempotency_key:, contracting_supplier_id: nil)
    ensure_hotel_times_paired!(occurrence_attributes)
    ActiveRecord::Base.transaction do
      created = arrangement || CreateSupplierArrangement.new(
        **hotel_command_context,
        departure: departure,
        idempotency_key: "#{idempotency_key}:arrangement",
        attributes: {
          name: item_name,
          contracting_supplier_id: contracting_supplier_id
        }
      ).call.record
      pin_authorized_version!(created, created.versions.sole) if arrangement.nil?

      version = reload_authorized_version!(created)
      item = CreateArrangementItem.new(
        **hotel_command_context,
        arrangement: created,
        version_lock_version: version.lock_version,
        idempotency_key: "#{idempotency_key}:item",
        attributes: {
          name: item_name,
          category: "lodging",
          default_service_provider_id: created.contracting_supplier_id
        }
      ).call.record

      version = reload_authorized_version!(created)
      definition = version.arrangement_item_definitions.find_by!(arrangement_item: item)
      SetItemCapacityManagement.new(
        **hotel_command_context,
        definition: definition,
        capacity_management: "managed",
        lock_version: definition.lock_version
      ).call

      version = reload_authorized_version!(created)
      CreateServiceOccurrence.new(
        **hotel_command_context,
        item: item,
        version_lock_version: version.lock_version,
        idempotency_key: "#{idempotency_key}:stay",
        attributes: occurrence_attributes.merge(name: "Stay")
      ).call

      [ created, item ]
    end
  end

  def hotel_command_error(error, template)
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    @form_error = error.message
    flash.now[:alert] = error.message
    assign_hotel_shape if @arrangement_item && @supplier_arrangement_version
    render template, status: :unprocessable_entity
  end

  def stay_occurrence_attributes
    occurrence = params.fetch(:occurrence, ActionController::Parameters.new).permit(
      :starts_on, :ends_on, :starts_at_local, :ends_at_local, :time_zone
    )
    occurrence.to_h
  end

  def ensure_hotel_times_paired!(attributes)
    values = attributes.to_h.with_indifferent_access
    return unless values[:starts_at_local].blank? ^ values[:ends_at_local].blank?

    raise AgencyCommand::Error.new(
      "Enter both a local start time and local end time, or leave both blank.",
      code: :invalid
    )
  end

  def hotel_agreement_editable?
    @supplier_arrangement_version.draft? &&
      @supplier_arrangement.editable_version&.id == @supplier_arrangement_version.id &&
      Current.agency_user.permitted?(:manage_departures)
  end

  def classify_stay_resource!(item:, stay_definition:, resource:)
    return if stay_definition.nil?

    version = reload_authorized_version!
    ClassifyCapacityPair.new(
      **hotel_command_context,
      item: item,
      service_occurrence: stay_definition.service_occurrence,
      supplier_resource: resource,
      classification: "not_applicable",
      version_lock_version: version.lock_version
    ).call
  end
end
