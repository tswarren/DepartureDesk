# frozen_string_literal: true

class CompositionServicesController < ApplicationController
  include DepartureAccess
  include CompositionAccess

  before_action :require_composition_access!
  before_action :set_departure
  before_action :ensure_composable_departure!

  def new
    @package_decision = params[:package_decision].presence || "yes"
    @component = component_defaults
    @selected_package = resolve_package_for_form
    @idempotency_key = SecureRandom.uuid
    @outcome = composition_outcome
  end

  def create
    @idempotency_key = params[:idempotency_key].presence || SecureRandom.uuid
    @package_decision = params[:package_decision].to_s
    @component = component_params.to_h
    @selected_package = resolve_package_for_form
    @return_intent = params[:return_intent].to_s
    @outcome = composition_outcome

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

    ctx = { outcome: @outcome, package_id: package_id }.compact
    if @return_intent == "add_another"
      redirect_to new_departure_composition_service_path(@departure, ctx), notice: "Service saved."
    else
      redirect_to services_departure_composition_path(@departure, ctx), notice: "Service saved."
    end
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    @component_error = error.message
    flash.now[:alert] = error.message
    render :new, status: :unprocessable_entity
  end

  private

  def first_component?
    @departure.service_offers.none? && @departure.packages.none?
  end

  def component_defaults
    {
      name: params[:name],
      client_timing_text: params[:client_timing_text]
    }
  end

  def component_params
    params.permit(:name, :client_timing_text)
  end

  def resolve_package_for_form
    id = params[:package_id].presence
    return if id.blank?

    package = Current.agency.packages.find_by(id: id, departure_id: @departure.id)
    raise ActiveRecord::RecordNotFound if package.nil?

    package
  end
end
