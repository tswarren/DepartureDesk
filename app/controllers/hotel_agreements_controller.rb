# frozen_string_literal: true

class HotelAgreementsController < ApplicationController
  include HotelArrangementAccess

  before_action :require_departure_view!
  before_action :set_departure
  before_action :ensure_composable_departure!
  before_action :set_supplier_arrangement
  before_action :set_hotel_agreement_version
  before_action :set_lodging_hotel_item
  before_action :assign_hotel_composition_context

  def show
    @hotel_agreement_page = true
    @agreement = HotelAgreementWorkspace.new(
      agency: Current.agency,
      departure: @departure,
      arrangement: @supplier_arrangement,
      version: @supplier_arrangement_version,
      item: @arrangement_item
    ).call
    @editable = hotel_agreement_editable?
  end
end
