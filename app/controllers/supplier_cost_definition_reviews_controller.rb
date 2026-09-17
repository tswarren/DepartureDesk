class SupplierCostDefinitionReviewsController < ApplicationController
  include SupplierCostAccess

  before_action :set_cost_source
  before_action :set_cost_definition

  def show
    render plain: "Cost definition review is coming in a later M3D.0 phase.",
      status: :not_implemented
  end
end
