# frozen_string_literal: true

class CruiseActiveVersionsController < ApplicationController
  include SupplierArrangementAccess

  before_action :require_departure_view!
  before_action :set_departure
  before_action :set_supplier_arrangement

  def show
    @supplier_arrangement_version = @supplier_arrangement.governing_version
    raise ActiveRecord::RecordNotFound unless @supplier_arrangement_version&.activated?

    @shape = DetectCruiseArrangementShape.new(
      agency: Current.agency,
      arrangement: @supplier_arrangement,
      version: @supplier_arrangement_version
    ).call
    raise ActiveRecord::RecordNotFound unless @shape.compatible?

    @summary = CompileCruiseCompositionSummary.new(
      agency: Current.agency,
      arrangement: @supplier_arrangement,
      shape: @shape
    ).call
    @activation = SupplierArrangementActivation.includes(:actor, supplier_confirmation: :supplier_issued_identifiers)
      .find_by(agency: Current.agency, supplier_arrangement_version: @supplier_arrangement_version)
    @draft_version = @supplier_arrangement.versions.find_by(status: "draft")
    @can_manage = Current.agency_user.permitted?(:manage_departures)
  end
end
