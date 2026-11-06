module Administration
  # The agency's default client cancellation tiers (BKG-31).
  class CancellationTiersController < BaseController
    FIELDS = %i[min_days_before_departure charge_kind percentage amount service_category].freeze
    LABELS = [ [ :min_days_before_departure, "Days before departure" ], [ :percentage, "Percentage" ], [ :amount, "Amount" ] ].freeze

    before_action :set_tier, only: %i[edit update destroy]

    def new
      @tier = Current.agency.agency_cancellation_tiers.new(charge_kind: "percentage")
      @values = {}
    end

    def create
      SaveCancellationTier.new(agency: Current.agency, actor: Current.agency_user, attributes: tier_params).call
      redirect_to administration_client_terms_defaults_path(anchor: "cancellation"), notice: "Tier saved."
    rescue AgencyCommand::Error => error
      @tier = Current.agency.agency_cancellation_tiers.new
      @values = tier_params
      render_error(error, :new)
    end

    def edit
      @values = TierFormValues.for(@tier)
    end

    def update
      SaveCancellationTier.new(agency: Current.agency, actor: Current.agency_user, tier: @tier, attributes: tier_params,
        lock_version: params.dig(:cancellation_tier, :lock_version)).call
      redirect_to administration_client_terms_defaults_path(anchor: "cancellation"), notice: "Tier saved."
    rescue AgencyCommand::Error => error
      @values = tier_params
      render_error(error, :edit)
    end

    def destroy
      RemoveCancellationTier.new(agency: Current.agency, actor: Current.agency_user, tier: @tier).call
      redirect_to administration_client_terms_defaults_path(anchor: "cancellation"), notice: "Tier removed."
    end

    private

    def set_tier
      @tier = Current.agency.agency_cancellation_tiers.find(params[:id])
    end

    def tier_params = params.require(:cancellation_tier).permit(*FIELDS).to_h

    def render_error(error, template)
      field, label = LABELS.find { |_field, text| error.message.start_with?(text) }
      field ? @tier.errors.add(field, error.message.delete_prefix(label).strip) : @tier.errors.add(:base, error.message)
      render template, status: :unprocessable_entity
    end
  end
end
