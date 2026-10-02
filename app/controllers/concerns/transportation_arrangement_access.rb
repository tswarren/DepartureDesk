# frozen_string_literal: true

module TransportationArrangementAccess
  extend ActiveSupport::Concern
  include DepartureAccess
  include CompositionAccess

  private

  def assign_transportation_workspace
    @outcome = composition_outcome
    @package_id = validated_composition_package_id
    @workspace = DepartureBuilderWorkspace.new(
      agency: Current.agency,
      departure: @departure,
      package_id: @package_id,
      require_explicit_package: true
    )
  end

  def set_transportation_arrangement
    @supplier_arrangement = @departure.supplier_arrangements.find(params[:arrangement_id])
  end

  def set_transportation_version
    version = if params[:version_id].present?
      @supplier_arrangement.versions.find(params[:version_id])
    else
      @supplier_arrangement.editable_version || @supplier_arrangement.governing_version
    end
    raise ActiveRecord::RecordNotFound if version.nil?

    @supplier_arrangement_version = version
  end

  def set_transportation_item
    @arrangement_item = @supplier_arrangement.arrangement_items.find(params[:id] || params[:item_id])
    @arrangement_item_definition = @supplier_arrangement_version.arrangement_item_definitions.find_by!(
      arrangement_item: @arrangement_item, category: "ground_transportation"
    )
  end

  def assign_transportation_agreement
    @agreement = CompileTransportationAgreement.new(
      agency: Current.agency,
      departure: @departure,
      arrangement: @supplier_arrangement,
      version: @supplier_arrangement_version
    ).call
    @editable = @agreement.editable && Current.agency_user.permitted?(:manage_departures)
  end

  def transportation_command_context
    { agency: Current.agency, actor: Current.agency_user }
  end

end
