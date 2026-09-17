class ArrangementItemSetupsController < ApplicationController
  include SupplierArrangementAccess

  COMMAND = CreateArrangementItemSetup

  before_action :require_departure_view!
  before_action :require_departure_management!
  before_action :set_departure
  before_action :set_supplier_arrangement
  before_action :set_editable_draft_version

  def new
    build_setup_records
    @idempotency_key = SecureRandom.uuid
  end

  def create
    build_setup_records
    @idempotency_key = params[:idempotency_key]

    unless setup_records_valid?
      return render :new, status: :unprocessable_entity
    end

    result = COMMAND.new(
      agency: Current.agency,
      actor: Current.agency_user,
      arrangement: @supplier_arrangement,
      item_attributes: item_params,
      occurrence_attributes: (occurrence_params if include_occurrence?),
      resource_attributes: (resource_params if include_resource?),
      version_lock_version: params[:version_lock_version],
      idempotency_key: @idempotency_key
    ).call

    redirect_to departure_arrangement_path(
      @departure, @supplier_arrangement, anchor: "item-#{result.record.item.id}"
    ), notice: "Item setup saved."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    add_setup_command_error(error)
    render :new, status: :unprocessable_entity
  end

  private

  def build_setup_records
    @include_occurrence = include_occurrence?
    @include_resource = include_resource?
    item = @supplier_arrangement.arrangement_items.new(
      agency: Current.agency, departure: @departure
    )
    @arrangement_item_definition = @supplier_arrangement_version.arrangement_item_definitions.new(
      item_params.merge(
        agency: Current.agency,
        departure: @departure,
        supplier_arrangement: @supplier_arrangement,
        arrangement_item: item,
        position: 1
      )
    )
    @service_occurrence_definition = @supplier_arrangement_version.service_occurrence_definitions.new(
      occurrence_params.merge(
        agency: Current.agency,
        departure: @departure,
        supplier_arrangement: @supplier_arrangement,
        arrangement_item: item,
        service_occurrence: item.service_occurrences.new(
          agency: Current.agency,
          departure: @departure,
          supplier_arrangement: @supplier_arrangement,
          status: "planned"
        ),
        time_zone: occurrence_params[:time_zone].presence || @departure.time_zone
      )
    )
    @supplier_resource_definition = @supplier_arrangement_version.supplier_resource_definitions.new(
      resource_params.merge(
        agency: Current.agency,
        departure: @departure,
        supplier_arrangement: @supplier_arrangement,
        arrangement_item: item,
        supplier_resource: item.supplier_resources.new(
          agency: Current.agency,
          departure: @departure,
          supplier_arrangement: @supplier_arrangement
        ),
        position: 1
      )
    )
  end

  def setup_records_valid?
    valid = @arrangement_item_definition.valid?
    valid = @service_occurrence_definition.valid? && valid if @include_occurrence
    valid = @supplier_resource_definition.valid? && valid if @include_resource
    valid
  end

  def add_setup_command_error(error)
    target =
      if error.message.match?(/occurrence|start date|end date|start time|end time|time zone/i)
        @service_occurrence_definition
      elsif error.message.match?(/resource/i)
        @supplier_resource_definition
      else
        @arrangement_item_definition
      end
    target.errors.add(:base, error.message)
  end

  def include_occurrence?
    ActiveModel::Type::Boolean.new.cast(params[:include_occurrence])
  end

  def include_resource?
    ActiveModel::Type::Boolean.new.cast(params[:include_resource])
  end

  def item_params
    params.fetch(:arrangement_item_definition, ActionController::Parameters.new).permit(
      :name, :description, :category, :other_category_label, :default_service_provider_id
    )
  end

  def occurrence_params
    params.fetch(:service_occurrence_definition, ActionController::Parameters.new).permit(
      :name, :description, :starts_on, :ends_on, :starts_at_local, :ends_at_local,
      :time_zone, :service_provider_id
    )
  end

  def resource_params
    params.fetch(:supplier_resource_definition, ActionController::Parameters.new).permit(
      :name, :description
    )
  end
end
