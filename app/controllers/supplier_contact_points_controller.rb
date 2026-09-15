class SupplierContactPointsController < ApplicationController
  include SupplierDirectoryAccess

  before_action :require_supplier_directory_management!
  before_action :set_supplier
  before_action :set_contact_point, only: %i[edit update edit_status update_status set_primary]

  def new
    @contact_point = contact_scope.new(preferred: false)
  end

  def create
    create_command.new(
      agency: Current.agency,
      actor: Current.agency_user,
      supplier: @supplier,
      attributes: contact_params,
      acknowledgement_token: acknowledgement_params[:acknowledgement_token],
      acknowledgement_reason: acknowledgement_params[:acknowledgement_reason]
    ).call
    redirect_to supplier_path(@supplier), notice: "#{channel_label} saved."
  rescue AgencyCommand::DuplicateReviewRequired => error
    @contact_point = contact_scope.new(contact_params)
    rescue_supplier_duplicate_review(error, :new)
  rescue AgencyCommand::Error => error
    @contact_point = contact_scope.new(contact_params)
    rescue_supplier_directory_error(error, :new)
  end

  def edit
  end

  def update
    update_command.new(
      agency: Current.agency,
      actor: Current.agency_user,
      supplier: @supplier,
      record: @contact_point,
      attributes: contact_params,
      lock_version: contact_params[:lock_version],
      acknowledgement_token: acknowledgement_params[:acknowledgement_token],
      acknowledgement_reason: acknowledgement_params[:acknowledgement_reason]
    ).call
    redirect_to supplier_path(@supplier), notice: "#{channel_label} updated."
  rescue AgencyCommand::DuplicateReviewRequired => error
    @contact_point.assign_attributes(contact_params.except(:lock_version))
    rescue_supplier_duplicate_review(error, :edit)
  rescue AgencyCommand::Error => error
    @contact_point.assign_attributes(contact_params.except(:lock_version))
    rescue_supplier_directory_error(error, :edit)
  end

  def set_primary
    result = set_primary_command.new(
      agency: Current.agency,
      actor: Current.agency_user,
      supplier: @supplier,
      record: @contact_point,
      lock_version: params.expect(:lock_version)
    ).call
    notice = result.status == :noop ? "#{channel_label} is already primary." : "#{channel_label} set as primary."
    redirect_to supplier_path(@supplier), notice: notice
  rescue AgencyCommand::Error => error
    redirect_to supplier_path(@supplier), alert: error.message
  end

  def edit_status
  end

  def update_status
    status_command.new(
      agency: Current.agency,
      actor: Current.agency_user,
      supplier: @supplier,
      record: @contact_point,
      status: params.expect(:status),
      lock_version: params.expect(:lock_version)
    ).call
    redirect_to supplier_path(@supplier), notice: "#{channel_label} status updated."
  rescue AgencyCommand::Error => error
    rescue_supplier_directory_error(error, :edit_status)
  end

  private

  def set_contact_point
    @contact_point = contact_scope.find(params[:contact_point_id])
  end
end
