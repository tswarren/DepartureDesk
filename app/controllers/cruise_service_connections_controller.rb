# frozen_string_literal: true

class CruiseServiceConnectionsController < ApplicationController
  include SupplierArrangementAccess

  before_action :require_cruise_connection_access!
  before_action :set_departure
  before_action :set_supplier_arrangement
  before_action :require_compatible_cruise_shape!
  before_action :assign_workspace

  def show
    @idempotency_key = SecureRandom.uuid
    assign_editor
    assign_form_defaults
  end

  def create
    @idempotency_key = params[:idempotency_key].presence || SecureRandom.uuid
    assign_editor_from_failure
    assign_form_from_params

    result = ConnectCruiseServiceOffer.new(
      agency: Current.agency,
      actor: Current.agency_user,
      arrangement: @supplier_arrangement,
      idempotency_key: @idempotency_key,
      attributes: connection_attributes
    ).call
    redirect_to departure_arrangement_cruise_service_connection_path(@departure, @supplier_arrangement),
      status: :see_other,
      notice: connection_notice(result.status)
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    assign_failure(error)
    render :show, status: :unprocessable_entity
  end

  def update
    offer = @workspace.offer || raise(ActiveRecord::RecordNotFound)
    @idempotency_key = params[:idempotency_key].presence || SecureRandom.uuid
    assign_editor_from_failure
    assign_form_from_params

    result = UpdateCruiseServiceConnection.new(
      agency: Current.agency,
      actor: Current.agency_user,
      offer: offer,
      idempotency_key: @idempotency_key,
      attributes: connection_attributes
    ).call
    redirect_to departure_arrangement_cruise_service_connection_path(@departure, @supplier_arrangement),
      status: :see_other,
      notice: connection_notice(result.status)
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    assign_failure(error)
    render :show, status: :unprocessable_entity
  end

  private

  def require_cruise_connection_access!
    raise ActiveRecord::RecordNotFound unless Current.agency_user&.permitted?(:manage_departures)
  end

  def require_compatible_cruise_shape!
    version, tentative = selected_sailing_version
    @sailing_tentative = tentative
    @supplier_arrangement_version = version
    @shape = DetectCruiseArrangementShape.new(
      agency: Current.agency,
      arrangement: @supplier_arrangement,
      version: version
    ).call
    return if @shape.compatible?

    redirect_to departure_arrangement_cruise_path(@departure, @supplier_arrangement),
      alert: "Open advanced Supplier planning for this Arrangement."
  end

  def selected_sailing_version
    draft = @supplier_arrangement.versions.find_by(status: "draft")
    governing = @supplier_arrangement.governing_version
    tentative = ActiveModel::Type::Boolean.new.cast(params[:use_tentative_draft]) || params[:sailing].to_s == "draft"
    if tentative && draft
      [ draft, true ]
    elsif governing
      [ governing, false ]
    else
      [ draft, true ]
    end
  end

  def assign_workspace
    @workspace = CompileCruiseServiceConnectionWorkspace.new(
      agency: Current.agency,
      arrangement: @supplier_arrangement,
      shape: @shape
    ).call
  end

  def assign_editor
    requested = params[:editor].to_s
    @editor_open = case @workspace.status
    when :not_connected, :decide_later
      requested == "connect"
    when :connected
      requested == "edit" && @workspace.editable
    else
      false
    end
  end

  def assign_editor_from_failure
    @editor_open = true
  end

  def assign_form_defaults
    definition = @workspace.definition
    @form = {
      title: definition&.client_title.presence || @supplier_arrangement.name,
      description: definition&.client_description,
      supplier_resource_ids: @workspace.categories.select(&:selected).map { |category| category.resource.id },
      service_offer_id: (@workspace.status == :decide_later ? @workspace.offer&.id : nil),
      arrangement_lock_version: @workspace.arrangement_version&.lock_version,
      version_lock_version: @workspace.version&.lock_version
    }
  end

  def assign_form_from_params
    @form = {
      title: params[:title],
      description: params[:description],
      supplier_resource_ids: Array(params[:supplier_resource_ids]),
      service_offer_id: params[:service_offer_id],
      arrangement_lock_version: params[:arrangement_lock_version],
      version_lock_version: params[:version_lock_version]
    }
  end

  def connection_attributes
    version = @sailing_tentative ? @supplier_arrangement.versions.find_by(status: "draft") : @supplier_arrangement_version
    version ||= @supplier_arrangement_version
    {
      mode: params[:mode],
      title: params[:title],
      description: params[:description],
      supplier_resource_ids: Array(params[:supplier_resource_ids]),
      service_offer_id: params[:service_offer_id],
      arrangement_item_id: @shape.item&.id,
      supplier_arrangement_version_id: version&.id,
      use_tentative_draft: @sailing_tentative,
      arrangement_lock_version: params[:arrangement_lock_version],
      version_lock_version: params[:version_lock_version]
    }
  end

  def assign_failure(error)
    @form_error = error.message
    flash.now[:alert] = error.message
  end

  def connection_notice(status)
    {
      created: "Cruise service created.",
      connected: "Cruise service connected.",
      outlined: "Saved for later.",
      updated: "Cruise service connection updated.",
      replayed: "Cruise service connection already saved."
    }.fetch(status.to_sym, "Cruise service connection saved.")
  end
end
