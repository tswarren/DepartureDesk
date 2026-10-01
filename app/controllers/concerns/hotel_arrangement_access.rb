# frozen_string_literal: true

module HotelArrangementAccess
  extend ActiveSupport::Concern

  include SupplierArrangementAccess
  include HotelCompositionContext

  private

  def set_hotel_version
    @supplier_arrangement_version = resolved_hotel_version
    raise ActiveRecord::RecordNotFound if @supplier_arrangement_version.nil?
  end

  def resolved_hotel_version
    if @supplier_arrangement.association(:versions).loaded?
      @supplier_arrangement.versions.find { |version| version.draft? } ||
        @supplier_arrangement.versions.find { |version| version.id == @supplier_arrangement.governing_version_id }
    else
      @supplier_arrangement.versions.find_by(status: "draft") ||
        @supplier_arrangement.governing_version
    end
  end

  def set_hotel_item
    @arrangement_item = @supplier_arrangement.arrangement_items.find(params[:item_id])
    @arrangement_item_definition = @supplier_arrangement_version.arrangement_item_definitions.find_by!(
      arrangement_item: @arrangement_item
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

  def reload_draft_version!
    @supplier_arrangement_version = @supplier_arrangement.versions.find_by!(status: "draft")
  end

  def hotel_command_context
    { agency: Current.agency, actor: Current.agency_user }
  end

  def save_new_hotel_stay!(departure:, arrangement:, item_name:, occurrence_attributes:, idempotency_key:, contracting_supplier_id: nil)
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

      version = created.versions.find_by!(status: "draft")
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

      version.reload
      definition = version.arrangement_item_definitions.find_by!(arrangement_item: item)
      SetItemCapacityManagement.new(
        **hotel_command_context,
        definition: definition,
        capacity_management: "managed",
        lock_version: definition.lock_version
      ).call

      version.reload
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

  def classify_stay_resource!(item:, stay_definition:, resource:)
    return if stay_definition.nil?

    version = reload_draft_version!
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
