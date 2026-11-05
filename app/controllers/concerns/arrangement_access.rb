module ArrangementAccess
  extend ActiveSupport::Concern
  include DepartureAccess

  private

  def require_arrangement_view!
    require_permission!(:view_arrangements)
  end

  def require_arrangement_management!
    require_permission!(:manage_arrangements)
  end

  def set_arrangement
    @arrangement = @departure.supplier_arrangements.find(params[:arrangement_id] || params[:id])
  end

  def can_view_supplier_costs?
    Current.agency_user.permitted?(:view_supplier_costs)
  end
  included { helper_method :can_view_supplier_costs? }

  def arrangement_params
    params.fetch(:supplier_arrangement, {}).permit(
      :supplier_id, :payee_account_id, :group_reference, :reservation_scope, :obligation_shape,
      :default_availability_promise, :covered_services, :terms, :lock_version
    )
  end

  def arrangement_error_attribute(message)
    case message
    when /supplier/i then :supplier_id
    when /payee/i then :payee_account_id
    when /reference/i then :group_reference
    when /currency/i then :base
    else :base
    end
  end
end
