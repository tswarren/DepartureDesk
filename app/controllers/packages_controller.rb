# frozen_string_literal: true

class PackagesController < ApplicationController
  include DepartureAccess

  before_action :require_unpublished_package_access!
  before_action :set_departure
  before_action :set_package, only: %i[show edit update abandon adopt include_published]
  before_action :set_editable_draft, only: %i[show edit update abandon adopt include_published]

  def index
    @search = ListDeparturePackages.call(agency: Current.agency, actor: Current.agency_user, departure: @departure)
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    @search = ListDeparturePackages::Outcome.new(records: [], truncated: false)
    flash.now[:alert] = error.message
    render :index, status: :unprocessable_entity
  end

  def show
    assign_preview
  end

  def new
    @package = @departure.packages.new
    @idempotency_key = SecureRandom.uuid
  end

  def create
    result = CreatePackageDraft.new(
      agency: Current.agency, actor: Current.agency_user, departure: @departure,
      attributes: package_params, idempotency_key: params[:idempotency_key]
    ).call
    redirect_to departure_package_path(@departure, result.record), notice: "Package draft saved."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    @package = @departure.packages.new(name: package_params[:name])
    @idempotency_key = params[:idempotency_key].presence || SecureRandom.uuid
    @package.errors.add(:base, error.message)
    flash.now[:alert] = error.message
    render :new, status: :unprocessable_entity
  end

  def edit
  end

  def update
    UpdatePackageDraft.new(
      agency: Current.agency, actor: Current.agency_user, package: @package,
      attributes: package_params,
      package_lock_version: params[:package_lock_version],
      version_lock_version: params[:version_lock_version]
    ).call
    redirect_to departure_package_path(@departure, @package), notice: "Package draft updated."
  rescue AgencyCommand::Error => error
    recover(error, :edit)
  end

  def abandon
    AbandonPackageDraft.new(
      agency: Current.agency, actor: Current.agency_user, package: @package,
      reason: params[:reason],
      package_lock_version: params[:package_lock_version],
      version_lock_version: params[:version_lock_version]
    ).call
    redirect_to departure_packages_path(@departure), notice: "Package draft abandoned."
  rescue AgencyCommand::Error => error
    recover(error, :show)
  end

  def inline
    set_package
    set_editable_draft
    CreatePackageInlineServiceOffer.new(
      agency: Current.agency, actor: Current.agency_user, package: @package,
      version_lock_version: params[:version_lock_version],
      idempotency_key: params[:idempotency_key],
      attributes: inline_params
    ).call
    redirect_to departure_package_path(@departure, @package), notice: "Service added to this package."
  rescue AgencyCommand::Error => error
    recover(error, :show)
  end

  def adopt
    offer = @departure.service_offers.find(params[:service_offer_id])
    AdoptServiceOfferDraftAsPackageOnly.new(
      agency: Current.agency, actor: Current.agency_user, package: @package, offer: offer,
      version_lock_version: params[:version_lock_version],
      offer_version_lock_version: params[:offer_version_lock_version],
      idempotency_key: params[:idempotency_key]
    ).call
    redirect_to departure_package_path(@departure, @package), notice: "Draft adopted as package-only."
  rescue AgencyCommand::Error => error
    recover(error, :show)
  end

  def include_published
    flash[:alert] = "No published reusable versions are available until publication ships."
    redirect_to departure_package_path(@departure, @package)
  end

  def preview
    set_package
    set_editable_draft
    assign_preview
    render :show
  end

  private

  def require_unpublished_package_access!
    raise ActiveRecord::RecordNotFound unless Current.agency_user&.permitted?(:manage_departures)
  end

  def set_package
    @package = @departure.packages.find(params[:id] || params[:package_id])
  end

  def set_editable_draft
    @package_version = @package.editable_draft_version || @package.versions.order(version_number: :desc).first ||
      raise(ActiveRecord::RecordNotFound)
  end

  def package_params
    params.fetch(:package, {}).permit(:name)
  end

  def inline_params
    params.fetch(:inline, {}).permit(
      :name, :client_title, :client_description, :fulfillment_basis, :placement,
      :supplier_arrangement_id, :supplier_arrangement_version_id, :arrangement_item_id,
      :service_occurrence_id, :supplier_resource_id, :capacity_pool_id
    )
  end

  def recover(error, template)
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    @package.errors.add(:base, error.message)
    flash.now[:alert] = error.message
    assign_preview
    render template, status: :unprocessable_entity
  end

  def assign_preview
    scenario = EvaluateClientPrice::Scenario.build(
      persons: params[:persons].presence || 2,
      selected_option_ids: Array(params[:selected_option_ids]),
      selected_binding_ids: Array(params[:selected_binding_ids])
    )
    @price_result = EvaluatePackagePrice.new(
      package: @package, version: @package_version, scenario: scenario,
      selected_inclusion_ids: Array(params[:selected_inclusion_ids])
    ).call if @package_version&.price_definition
    @economics = if @price_result && Current.agency_user.permitted?(:manage_departures)
      EvaluatePackageIndicativeEconomics.new(
        agency: Current.agency, actor: Current.agency_user, package: @package,
        version: @package_version, scenario: scenario,
        selected_inclusion_ids: Array(params[:selected_inclusion_ids])
      ).call
    end
    @adoptable_drafts = @departure.service_offers.includes(:versions).select { |offer|
      version = offer.editable_draft_version
      version && version.owning_package_version_id.nil?
    }
  end
end
