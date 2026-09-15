class SupplierContactsController < ApplicationController
  include SupplierDirectoryAccess

  before_action :require_supplier_directory_view!
  before_action :require_supplier_contact_details!
  before_action :require_supplier_directory_management!, except: %i[show]
  before_action :set_supplier
  before_action :set_supplier_contact, only: %i[show edit update edit_status update_status preferred]

  def show
    @email_addresses = @supplier_contact.email_addresses.preferred_first
    @phone_numbers = @supplier_contact.phone_numbers.preferred_first
  end

  def new
    @supplier_contact = @supplier.contacts.new
  end

  def create
    result = CreateSupplierContact.new(
      agency: Current.agency,
      actor: Current.agency_user,
      supplier: @supplier,
      attributes: contact_params,
      acknowledgement_token: acknowledgement_params[:acknowledgement_token],
      acknowledgement_reason: acknowledgement_params[:acknowledgement_reason]
    ).call
    redirect_to supplier_contact_path(@supplier, result.record), notice: "Contact saved."
  rescue AgencyCommand::DuplicateReviewRequired => error
    @supplier_contact = @supplier.contacts.new(contact_params.except(:lock_version))
    rescue_supplier_duplicate_review(error, :new)
  rescue AgencyCommand::Error => error
    @supplier_contact = @supplier.contacts.new(contact_params.except(:lock_version))
    rescue_supplier_directory_error(error, :new)
  end

  def edit
  end

  def update
    UpdateSupplierContact.new(
      agency: Current.agency,
      actor: Current.agency_user,
      supplier: @supplier,
      supplier_contact: @supplier_contact,
      attributes: contact_params,
      lock_version: contact_params[:lock_version],
      acknowledgement_token: acknowledgement_params[:acknowledgement_token],
      acknowledgement_reason: acknowledgement_params[:acknowledgement_reason]
    ).call
    redirect_to supplier_contact_path(@supplier, @supplier_contact), notice: "Contact updated."
  rescue AgencyCommand::DuplicateReviewRequired => error
    @supplier_contact.assign_attributes(contact_params.except(:lock_version))
    rescue_supplier_duplicate_review(error, :edit)
  rescue AgencyCommand::Error => error
    @supplier_contact.assign_attributes(contact_params.except(:lock_version))
    rescue_supplier_directory_error(error, :edit)
  end

  def edit_status
    @affected_destinations = contact_owned_destinations.select(&:active?)
  end

  def update_status
    ChangeSupplierContactStatus.new(
      agency: Current.agency,
      actor: Current.agency_user,
      supplier: @supplier,
      supplier_contact: @supplier_contact,
      status: params.expect(:status),
      lock_version: params.expect(:lock_version)
    ).call
    redirect_to supplier_contact_path(@supplier, @supplier_contact), notice: "Contact status updated."
  rescue AgencyCommand::Error => error
    @affected_destinations = contact_owned_destinations.select(&:active?)
    rescue_supplier_directory_error(error, :edit_status)
  end

  def preferred
    result = SetPreferredSupplierContact.new(
      agency: Current.agency,
      actor: Current.agency_user,
      supplier: @supplier,
      supplier_contact: @supplier_contact,
      preferred: params.expect(:preferred),
      lock_version: params.expect(:lock_version)
    ).call
    notice = if result.status == :noop
      result.record.preferred? ? "Contact is already preferred." : "Contact is already not preferred."
    elsif ActiveModel::Type::Boolean.new.cast(params[:preferred])
      "Preferred contact updated."
    else
      "Preferred contact cleared."
    end
    redirect_to supplier_path(@supplier), notice: notice
  rescue AgencyCommand::Error => error
    redirect_to supplier_path(@supplier), alert: error.message
  end

  private

  def contact_params
    params.expect(supplier_contact: %i[first_name last_name title department role_label lock_version])
  end

  def contact_owned_destinations
    @supplier_contact.email_addresses.to_a + @supplier_contact.phone_numbers.to_a
  end
end
