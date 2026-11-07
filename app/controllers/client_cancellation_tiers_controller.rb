# A Departure's override of the agency cancellation tiers (BKG-31).
class ClientCancellationTiersController < ApplicationController
  include PackageAccess

  FIELDS = %i[min_days_before_departure charge_kind percentage amount service_category].freeze
  LABELS = [ [ :min_days_before_departure, "Days before departure" ], [ :percentage, "Percentage" ], [ :amount, "Amount" ] ].freeze

  before_action :require_departure_view!
  before_action :require_package_management!
  before_action :set_departure
  before_action :set_terms_version
  before_action :set_tier, only: %i[edit update destroy]

  def new
    @tier = @terms_version.own_cancellation_tiers.new(charge_kind: "percentage")
    @values = {}
  end

  def create
    SaveCancellationTier.new(agency: Current.agency, actor: Current.agency_user, departure: @departure, terms_version: @terms_version, attributes: tier_params).call
    redirect_to departure_client_terms_path(@departure, anchor: "cancellation"), notice: "Tier saved."
  rescue AgencyCommand::Error => error
    @tier = @terms_version.own_cancellation_tiers.new
    @values = tier_params
    render_form_error(error, @tier, :new, LABELS)
  end

  def edit
    @values = TierFormValues.for(@tier)
  end

  def update
    SaveCancellationTier.new(agency: Current.agency, actor: Current.agency_user, departure: @departure, terms_version: @terms_version, tier: @tier,
      attributes: tier_params, lock_version: params.dig(:cancellation_tier, :lock_version)).call
    redirect_to departure_client_terms_path(@departure, anchor: "cancellation"), notice: "Tier saved."
  rescue AgencyCommand::Error => error
    @values = tier_params
    render_form_error(error, @tier, :edit, LABELS)
  end

  def destroy
    RemoveCancellationTier.new(agency: Current.agency, actor: Current.agency_user, departure: @departure, terms_version: @terms_version, tier: @tier).call
    redirect_to departure_client_terms_path(@departure, anchor: "cancellation"), notice: "Tier removed."
  rescue AgencyCommand::Error => error
    redirect_to departure_client_terms_path(@departure, anchor: "cancellation"), alert: error.message
  end

  private

  def set_tier
    @tier = @terms_version.own_cancellation_tiers.find(params[:id])
  end

  def tier_params = form_params(:cancellation_tier, FIELDS)
end
