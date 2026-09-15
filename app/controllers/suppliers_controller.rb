class SuppliersController < ApplicationController
  include SupplierDirectoryAccess

  before_action :require_supplier_directory_view!
  before_action :require_supplier_directory_management!, except: %i[index show]
  before_action :set_supplier, except: %i[index new create]

  def index
    @status = SearchSupplierDirectory::STATUSES.include?(params[:status]) ? params[:status] : "active"
    @kind = SearchSupplierDirectory::KINDS.include?(params[:kind]) ? params[:kind] : "all"
    @category = SupplierCategory::CODES.include?(params[:category]) ? params[:category] : "all"
    @search = SearchSupplierDirectory.call(
      agency: Current.agency,
      actor: Current.agency_user,
      query: params[:q],
      status: @status,
      kind: @kind,
      category: @category
    )
  rescue AgencyCommand::Error => error
    @search = SearchSupplierDirectory::Outcome.new(records: [], truncated: false)
    flash.now[:alert] = error.message
    render :index, status: :unprocessable_entity
  end

  def new
    @supplier = supplier_directory.new(kind: params[:kind].presence_in(Supplier::KINDS) || "organization")
  end

  def create
    result = CreateSupplier.new(
      agency: Current.agency,
      actor: Current.agency_user,
      kind: supplier_kind_param,
      names: supplier_names_params,
      categories: supplier_category_rows,
      acknowledgement_token: acknowledgement_params[:acknowledgement_token],
      acknowledgement_reason: acknowledgement_params[:acknowledgement_reason]
    ).call
    redirect_to supplier_path(result.record), notice: "Supplier saved."
  rescue AgencyCommand::DuplicateReviewRequired => error
    @supplier = supplier_directory.new(supplier_names_params.except(:lock_version).merge(kind: supplier_kind_param))
    build_category_assignments
    rescue_supplier_duplicate_review(error, :new)
  rescue AgencyCommand::Error => error
    @supplier = supplier_directory.new(supplier_names_params.except(:lock_version).merge(kind: supplier_kind_param))
    build_category_assignments
    rescue_supplier_directory_error(error, :new)
  end

  def show
    @category_assignments = @supplier.category_assignments.order(:category_code)
    return unless can_view_supplier_contact_details?

    @email_addresses = @supplier.email_addresses.preferred_first
    @phone_numbers = @supplier.phone_numbers.preferred_first
    @postal_addresses = @supplier.postal_addresses.preferred_first
    @websites = @supplier.websites.preferred_first
  end

  def edit
  end

  def update
    UpdateSupplier.new(
      agency: Current.agency,
      actor: Current.agency_user,
      supplier: @supplier,
      names: supplier_names_params,
      lock_version: supplier_names_params[:lock_version],
      acknowledgement_token: acknowledgement_params[:acknowledgement_token],
      acknowledgement_reason: acknowledgement_params[:acknowledgement_reason]
    ).call
    redirect_to supplier_path(@supplier), notice: "Supplier updated."
  rescue AgencyCommand::DuplicateReviewRequired => error
    @supplier.assign_attributes(supplier_names_params.except(:lock_version))
    rescue_supplier_duplicate_review(error, :edit)
  rescue AgencyCommand::Error => error
    @supplier.assign_attributes(supplier_names_params.except(:lock_version))
    rescue_supplier_directory_error(error, :edit)
  end

  def edit_status
    @affected_contact_points = supplier_contact_points.select(&:active?)
  end

  def update_status
    ChangeSupplierStatus.new(
      agency: Current.agency,
      actor: Current.agency_user,
      supplier: @supplier,
      status: params.expect(:status),
      lock_version: params.expect(:lock_version)
    ).call
    redirect_to supplier_path(@supplier), notice: "Supplier status updated."
  rescue AgencyCommand::Error => error
    @affected_contact_points = supplier_contact_points.select(&:active?)
    rescue_supplier_directory_error(error, :edit_status)
  end

  def edit_categories
    @category_assignments = @supplier.category_assignments.order(:category_code)
  end

  def update_categories
    ReplaceSupplierCategories.new(
      agency: Current.agency,
      actor: Current.agency_user,
      supplier: @supplier,
      categories: supplier_category_rows,
      lock_version: params.expect(:lock_version)
    ).call
    redirect_to supplier_path(@supplier), notice: "Supplier categories updated."
  rescue AgencyCommand::Error => error
    build_category_assignments
    rescue_supplier_directory_error(error, :edit_categories)
  end

  private

  def build_category_assignments
    @category_assignments = supplier_category_rows.filter_map do |row|
      code = row[:category_code].presence
      next if code.blank?

      @supplier.category_assignments.build(row)
    end
  end

  def supplier_contact_points
    @supplier.email_addresses.to_a +
      @supplier.phone_numbers.to_a +
      @supplier.postal_addresses.to_a +
      @supplier.websites.to_a
  end
end
