module SupplierArrangementAccess
  extend ActiveSupport::Concern

  include DepartureAccess

  included do
    helper_method :active_supplier_options
  end

  private

  def set_departure
    @departure = departures_scope.find(params[:departure_id])
  end

  def set_supplier_arrangement
    @supplier_arrangement = @departure.supplier_arrangements.find(params[:arrangement_id] || params[:id])
  end

  def set_initial_version
    @supplier_arrangement_version = @supplier_arrangement.versions.find_by!(version_number: 1)
  end

  def set_arrangement_item
    @arrangement_item = @supplier_arrangement.arrangement_items.find(params[:item_id] || params[:id])
  end

  def set_item_definition
    @arrangement_item_definition = @supplier_arrangement_version.arrangement_item_definitions.find_by!(
      arrangement_item: @arrangement_item
    )
  end

  def set_service_occurrence
    @service_occurrence = @arrangement_item.service_occurrences.find(params[:occurrence_id] || params[:id])
  end

  def set_service_occurrence_definition
    @service_occurrence_definition = @supplier_arrangement_version.service_occurrence_definitions.find_by!(
      service_occurrence: @service_occurrence
    )
  end

  def set_supplier_resource
    @supplier_resource = @arrangement_item.supplier_resources.find(params[:resource_id] || params[:id])
  end

  def set_supplier_resource_definition
    @supplier_resource_definition = @supplier_arrangement_version.supplier_resource_definitions.find_by!(
      supplier_resource: @supplier_resource
    )
  end

  def active_supplier_options
    Current.agency.suppliers.where(status: "active").ordered_for_directory
  end

  def arrangement_error_attribute(message)
    case message
    when /contact/i then :supplier_contact_id
    when /supplier|provider/i then :contracting_supplier_id
    when /name/i then :name
    when /category/i then :category
    when /description/i then :description
    when /start date/i then :starts_on
    when /end date/i then :ends_on
    when /time zone|timezone/i then :time_zone
    when /reason/i then :abandoned_reason
    else :base
    end
  end

  def add_arrangement_error(record, error)
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    if error.code == :invalid
      record.errors.add(arrangement_error_attribute(error.message), error.message)
    else
      flash.now[:alert] = error.message
    end
  end
end
