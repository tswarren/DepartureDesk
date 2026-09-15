class SupplierLocationsController < ApplicationController
  include SupplierDirectoryAccess

  before_action :require_supplier_directory_view!
  before_action :require_supplier_directory_management!, except: %i[show]
  before_action :set_supplier
  before_action :set_supplier_location, only: %i[show edit update edit_status update_status]

  def show
  end

  def new
    @supplier_location = @supplier.locations.new
  end

  def create
    result = CreateSupplierLocation.new(
      agency: Current.agency,
      actor: Current.agency_user,
      supplier: @supplier,
      attributes: location_params,
      acknowledgement_token: acknowledgement_params[:acknowledgement_token],
      acknowledgement_reason: acknowledgement_params[:acknowledgement_reason]
    ).call
    redirect_to supplier_location_path(@supplier, result.record), notice: "Location saved."
  rescue AgencyCommand::DuplicateReviewRequired => error
    @supplier_location = @supplier.locations.new(location_params.except(:lock_version))
    rescue_supplier_duplicate_review(error, :new)
  rescue AgencyCommand::Error => error
    @supplier_location = @supplier.locations.new(location_params.except(:lock_version))
    rescue_supplier_directory_error(error, :new)
  end

  def edit
  end

  def update
    UpdateSupplierLocation.new(
      agency: Current.agency,
      actor: Current.agency_user,
      supplier: @supplier,
      supplier_location: @supplier_location,
      attributes: location_params,
      lock_version: location_params[:lock_version],
      acknowledgement_token: acknowledgement_params[:acknowledgement_token],
      acknowledgement_reason: acknowledgement_params[:acknowledgement_reason]
    ).call
    redirect_to supplier_location_path(@supplier, @supplier_location), notice: "Location updated."
  rescue AgencyCommand::DuplicateReviewRequired => error
    @supplier_location.assign_attributes(location_params.except(:lock_version))
    rescue_supplier_duplicate_review(error, :edit)
  rescue AgencyCommand::Error => error
    @supplier_location.assign_attributes(location_params.except(:lock_version))
    rescue_supplier_directory_error(error, :edit)
  end

  def edit_status
  end

  def update_status
    ChangeSupplierLocationStatus.new(
      agency: Current.agency,
      actor: Current.agency_user,
      supplier: @supplier,
      supplier_location: @supplier_location,
      status: params.expect(:status),
      lock_version: params.expect(:lock_version)
    ).call
    redirect_to supplier_location_path(@supplier, @supplier_location), notice: "Location status updated."
  rescue AgencyCommand::Error => error
    rescue_supplier_directory_error(error, :edit_status)
  end

  private

  def location_params
    params.expect(
      supplier_location: %i[
        name timezone
        address_line_1 address_line_2 address_locality address_region address_postal_code address_country_code
        phone_number phone_extension phone_country_code
        lock_version
      ]
    )
  end
end
