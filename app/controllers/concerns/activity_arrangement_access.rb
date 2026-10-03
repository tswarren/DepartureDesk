# frozen_string_literal: true

module ActivityArrangementAccess
  extend ActiveSupport::Concern
  include DepartureAccess
  include CompositionAccess

  private

  def assign_activity_workspace
    @outcome = composition_outcome
    @package_id = validated_composition_package_id
    @workspace = DepartureBuilderWorkspace.new(
      agency: Current.agency, departure: @departure, package_id: @package_id, require_explicit_package: true
    )
  end

  def set_activity_arrangement
    @supplier_arrangement = @departure.supplier_arrangements.find(params[:arrangement_id])
  end

  def set_activity_version
    version = if params[:version_id].present?
      @supplier_arrangement.versions.find(params[:version_id])
    else
      @supplier_arrangement.editable_version || @supplier_arrangement.governing_version
    end
    raise ActiveRecord::RecordNotFound if version.nil?

    @supplier_arrangement_version = version
  end

  def assign_activity_agreement
    @agreement = CompileActivityAgreement.new(
      agency: Current.agency, departure: @departure,
      arrangement: @supplier_arrangement, version: @supplier_arrangement_version
    ).call
    @editable = @agreement.editable && Current.agency_user.permitted?(:manage_departures)
  end

  def activity_command_context
    { agency: Current.agency, actor: Current.agency_user }
  end

  def active_supplier_options
    Current.agency.suppliers.where(status: "active").ordered_for_directory
  end
end
