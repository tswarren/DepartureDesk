# frozen_string_literal: true

class DepartureCompositionsController < ApplicationController
  include DepartureAccess
  include CompositionAccess

  before_action :require_composition_access!
  before_action :set_departure
  before_action :ensure_composable_departure!
  before_action :assign_composition_context

  def show
    assign_overview
    render :show
  end

  def services
    assign_services
    render :services
  end

  def suppliers
    listing = ListDepartureArrangements.call(
      agency: Current.agency,
      actor: Current.agency_user,
      departure: @departure
    )
    @arrangements = listing.records
    @cruise_shapes = @arrangements.index_with do |arrangement|
      DetectCruiseArrangementShape.new(
        agency: Current.agency,
        arrangement: arrangement
      ).call
    end
    render :suppliers
  end

  def package
    assign_package_area
    render :package
  end

  def review
    assign_review
    render :review
  end

  private

  def assign_composition_context
    @outcome = composition_outcome
    @package_id = validated_composition_package_id
    @workspace = DepartureBuilderWorkspace.new(
      agency: Current.agency,
      departure: @departure,
      package_id: @package_id,
      work_on: composition_work_on_for_workspace,
      require_explicit_package: true
    )
    @readiness = @workspace.readiness
    @recommendation = RecommendDepartureBuilderAction.new(
      agency: Current.agency,
      departure: @departure,
      readiness: @readiness,
      outcome: @outcome
    ).call
    @area_summaries = SummarizeDepartureCompositionAreas.new(
      agency: Current.agency,
      actor: Current.agency_user,
      departure: @departure,
      outcome: @outcome,
      package: @workspace.selected_package,
      readiness: @readiness
    ).call
  end

  def assign_overview
    @empty_composition = empty_composition?
  end

  def assign_services
    @component_cards = @workspace.service_map_cards
  end

  def assign_package_area
    @selected_package = @workspace.selected_package
    @editable_packages = @workspace.editable_packages
  end

  def assign_review
    @selected_package = @workspace.selected_package
    @findings = @readiness.findings.select { |finding| finding.applicable_to?(@outcome || "proposal") }
    @findings = @readiness.findings if @findings.empty? && @outcome.blank?
    if @selected_package
      @common_scenarios = DeriveCommonPackageScenarios.new(
        agency: Current.agency,
        package: @selected_package
      ).call
    end
  end

  def empty_composition?
    @workspace.editable_packages.empty? &&
      @departure.service_offers.none? { |offer| offer.editable_draft_version.present? } &&
      @departure.supplier_arrangements.none?
  end

  def composition_work_on_for_workspace
    case @outcome
    when "proposal" then "preview"
    when "supplier", "pricing" then @outcome
    else nil
    end
  end
end
