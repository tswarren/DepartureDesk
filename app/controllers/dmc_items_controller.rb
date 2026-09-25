# frozen_string_literal: true

class DmcItemsController < ApplicationController
  include SupplierArrangementAccess

  before_action :require_slice3_access!
  before_action :set_departure
  before_action :set_supplier_arrangement

  def show
    @rows = CompileDmcItemTable.new(agency: Current.agency, arrangement: @supplier_arrangement).call
  end

  private

  def require_slice3_access!
    raise ActiveRecord::RecordNotFound unless Current.agency_user&.permitted?(:manage_departures)
  end
end
