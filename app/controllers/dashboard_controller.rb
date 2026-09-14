class DashboardController < ApplicationController
  def show
    @offices = Current.agency.offices.order(:name)
  end
end
