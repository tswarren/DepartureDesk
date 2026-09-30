# frozen_string_literal: true

# Shared assigns for the Cruise Supplier agreement review page.
module CruiseAgreementReview
  extend ActiveSupport::Concern

  AGREEMENT_RETURN_TOKEN = "agreement"

  def agreement_return?
    params[:return_to].to_s == AGREEMENT_RETURN_TOKEN
  end

  def assign_cruise_agreement_review!
    @shape = DetectCruiseArrangementShape.new(
      agency: Current.agency,
      arrangement: @supplier_arrangement
    ).call
    @supplier_arrangement_version = @shape.version
    @can_manage = Current.agency_user.permitted?(:manage_departures)
    @editable = @supplier_arrangement_version&.draft? && @can_manage
    version = @supplier_arrangement_version
    @commercial_benefits = if @shape.compatible? && version
      version.supplier_arrangement_commercial_benefit_definitions
        .includes(:copied_from)
        .order(:term_type)
        .to_a
    else
      []
    end
    @agreement_confirmation = version&.supplier_arrangement_cruise_agreement_confirmations
      &.includes(:confirmed_by)
      &.find_by(current: true)
    @agreement_terms = version&.supplier_arrangement_cruise_term_definitions&.order(:term_type, :position)&.to_a || []
    @cabin_pool_ids = version&.capacity_pool_definitions&.order(:position, :id)&.map(&:capacity_pool_id) || []
    @requirements_workspace = if @shape.compatible? && version
      CompileCruiseDepositsAndDeadlinesWorkspace.new(
        agency: Current.agency,
        arrangement: @supplier_arrangement,
        version: version
      ).call
    end
    @focus = params[:focus].to_s
    @highlight = params[:highlight].to_s
  end

  def agreement_page_path(highlight:)
    departure_arrangement_cruise_agreement_path(
      @departure,
      @supplier_arrangement,
      highlight: highlight
    )
  end

  def render_agreement_review_error(error, focus:)
    assign_cruise_agreement_review!
    @focus = focus
    @form_error = error.message
    flash.now[:alert] = error.message
    render "cruise_agreements/show", status: :unprocessable_entity
  end
end
