# frozen_string_literal: true

class PackagesController < ApplicationController
  include DepartureAccess

  before_action :require_unpublished_package_access!
  before_action :set_departure
  before_action :set_package, only: %i[show edit update abandon adopt include_published publish pause_sales resume_sales retire successor]
  before_action :set_package_version, only: %i[show edit update abandon adopt include_published publish pause_sales resume_sales retire successor preview]

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
    destination = if params[:return_to] == "builder"
      departure_path(@departure, work_on: params[:work_on].presence || "supplier", package_id: @package.id)
    else
      departure_package_path(@departure, @package)
    end
    redirect_to destination, notice: "Service added to this package."
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
    IncludePublishedReusableServiceOfferVersion.new(
      agency: Current.agency, actor: Current.agency_user, package: @package,
      version_lock_version: params[:version_lock_version],
      service_offer_version_id: params[:service_offer_version_id],
      placement: params[:placement],
      idempotency_key: params[:idempotency_key]
    ).call
    redirect_to departure_package_path(@departure, @package), notice: "Published service included."
  rescue AgencyCommand::Error => error
    recover(error, :show)
  end

  def publish
    PublishPackageVersion.new(
      agency: Current.agency, actor: Current.agency_user, package: @package,
      version_lock_version: params[:version_lock_version],
      sales_enabled: params[:sales_enabled] != "0",
      idempotency_key: params[:idempotency_key].presence || SecureRandom.uuid
    ).call
    redirect_to departure_package_path(@departure, @package), notice: "Package published."
  rescue AgencyCommand::Error => error
    recover(error, :show)
  end

  def pause_sales
    PausePackageSales.new(agency: Current.agency, actor: Current.agency_user, package: @package).call
    redirect_to departure_package_path(@departure, @package), notice: "Sales paused."
  rescue AgencyCommand::Error => error
    recover(error, :show)
  end

  def resume_sales
    ResumePackageSales.new(agency: Current.agency, actor: Current.agency_user, package: @package).call
    redirect_to departure_package_path(@departure, @package), notice: "Sales resumed."
  rescue AgencyCommand::Error => error
    recover(error, :show)
  end

  def retire
    RetirePackageVersion.new(
      agency: Current.agency, actor: Current.agency_user, package: @package, reason: params[:reason]
    ).call
    redirect_to departure_packages_path(@departure), notice: "Package version retired."
  rescue AgencyCommand::Error => error
    recover(error, :show)
  end

  def successor
    CreatePackageSuccessorDraft.new(
      agency: Current.agency, actor: Current.agency_user, package: @package,
      version_lock_version: params[:version_lock_version],
      idempotency_key: params[:idempotency_key].presence || SecureRandom.uuid
    ).call
    redirect_to departure_package_path(@departure, @package), notice: "Successor draft created."
  rescue AgencyCommand::Error => error
    recover(error, :show)
  end

  def preview
    set_package
    set_package_version
    assign_preview
    render :show
  end

  private

  def require_unpublished_package_access!
    raise ActiveRecord::RecordNotFound unless Current.agency_user&.permitted?(:manage_departures) ||
      (action_name == "show" && Current.agency_user&.permitted?(:view_departures))
  end

  def set_package
    @package = @departure.packages.find(params[:id] || params[:package_id])
  end

  def set_package_version
    manage = Current.agency_user.permitted?(:manage_departures)
    @package_version = if manage
      @package.editable_draft_version || @package.current_published_version ||
        @package.versions.order(version_number: :desc).first
    else
      @package.current_published_version
    end
    raise ActiveRecord::RecordNotFound if @package_version.nil?
    if !manage && !@package_version.published?
      raise ActiveRecord::RecordNotFound
    end
  end

  def set_editable_draft
    set_package_version
  end

  def package_params
    params.fetch(:package, {}).permit(:name)
  end

  def inline_params
    params.fetch(:inline, {}).permit(
      :name, :client_title, :client_description, :client_timing_text, :fulfillment_basis, :placement,
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
    @selected_inclusion_ids = Array(params[:selected_inclusion_ids]).map(&:to_s)
    @selected_option_ids = Array(params[:selected_option_ids]).map(&:to_s)
    @preview_persons = params[:persons].presence || 2
    @can_manage_offers = Current.agency_user.permitted?(:manage_departures)
    @review_inclusions = if @package_version
      @package_version.inclusions.includes(
        :service_offer,
        service_offer_version: { choice_groups: :service_offer_choice_options }
      ).order(:position).to_a
    else
      []
    end
    @price_result = EvaluatePackagePrice.new(
      package: @package, version: @package_version, scenario: scenario,
      selected_inclusion_ids: @selected_inclusion_ids
    ).call if @package_version&.price_definition
    @economics = if @price_result && @can_manage_offers
      EvaluatePackageIndicativeEconomics.new(
        agency: Current.agency, actor: Current.agency_user, package: @package,
        version: @package_version, scenario: scenario,
        selected_inclusion_ids: @selected_inclusion_ids
      ).call
    end
    sov = @package_version&.owned_service_offer_versions&.first ||
      @package_version&.inclusions&.first&.service_offer_version
    @live_feasibility = if @package_version&.published? && sov
      EvaluateOfferLiveFeasibility.new(
        agency: Current.agency,
        version: sov,
        package_version: @package_version,
        scenario: scenario,
        selected_inclusion_ids: @selected_inclusion_ids
      ).call
    end
    @published_reusable_versions = if @can_manage_offers && @package_version&.draft?
      ServiceOfferVersion.joins(:service_offer)
        .where(agency_id: Current.agency.id, status: "published", owning_package_version_id: nil)
        .where(service_offers: { departure_id: @departure.id })
        .includes(:service_offer, :sales_state)
        .order("service_offers.name")
        .select { |version| version.sales_state&.sales_enabled != false }
    else
      []
    end
    @adoptable_drafts = if @can_manage_offers
      @departure.service_offers.includes(:versions).select { |offer|
        version = offer.editable_draft_version
        version && version.owning_package_version_id.nil?
      }
    else
      []
    end
  end
end
