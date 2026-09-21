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
    @locations = @supplier.locations.ordered_for_directory
    return unless can_view_supplier_contact_details?

    @contacts = @supplier.contacts.preferred_first
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
    load_status_inventory
  end

  def update_status
    force_allowed = Current.agency_user.permitted?(:force_inactivate_supplier_with_dependencies)
    ChangeSupplierStatus.new(
      agency: Current.agency,
      actor: Current.agency_user,
      supplier: @supplier,
      status: params.expect(:status),
      lock_version: params.expect(:lock_version),
      force: force_allowed && ActiveModel::Type::Boolean.new.cast(params[:force]),
      force_reason: (params[:force_reason] if force_allowed)
    ).call
    redirect_to supplier_path(@supplier), notice: "Supplier status updated."
  rescue AgencyCommand::Error => error
    @force_reason = params[:force_reason]
    load_status_inventory
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

  def load_status_inventory
    @affected_locations = @supplier.locations.select(&:active?)
    contacts = @supplier.contacts.includes(:email_addresses, :phone_numbers).to_a
    @affected_contacts = contacts.select(&:active?)
    @affected_contact_points = supplier_owned_contact_points.select(&:active?)
    @affected_contact_destinations = contacts.flat_map { |contact|
      contact.email_addresses.to_a + contact.phone_numbers.to_a
    }.select(&:active?)
    @affected_supplier_arrangements = @supplier.contracted_supplier_arrangements
      .includes(:departure)
      .where(status: %w[draft active])
      .order(:name, :id)
      .to_a
    @affected_effective_provider_arrangements = ServiceOccurrenceDefinition
      .joins(:service_occurrence, :supplier_arrangement)
      .joins(<<~SQL.squish)
        JOIN arrangement_item_definitions
          ON arrangement_item_definitions.supplier_arrangement_version_id = service_occurrence_definitions.supplier_arrangement_version_id
         AND arrangement_item_definitions.arrangement_item_id = service_occurrence_definitions.arrangement_item_id
      SQL
      .includes(:departure, :supplier_arrangement)
      .where(agency_id: Current.agency.id)
      .where(service_occurrences: { status: "planned" })
      .where(supplier_arrangements: { status: %w[draft active] })
      .where("service_occurrence_definitions.ends_on >= (CURRENT_TIMESTAMP AT TIME ZONE service_occurrence_definitions.time_zone)::date")
      .where(
        "COALESCE(service_occurrence_definitions.service_provider_id, arrangement_item_definitions.default_service_provider_id, supplier_arrangements.contracting_supplier_id) = ?",
        @supplier.id
      )
      .distinct
      .order(:supplier_arrangement_id, :id)
      .to_a
    @offer_path_consequences = ListPublishedOfferPathConsequences.new(
      agency: Current.agency, supplier: @supplier
    ).call
  end

  def supplier_owned_contact_points
    @supplier.email_addresses.to_a +
      @supplier.phone_numbers.to_a +
      @supplier.postal_addresses.to_a +
      @supplier.websites.to_a
  end
end
