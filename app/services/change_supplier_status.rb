class ChangeSupplierStatus < AgencyCommand
  include DepartureCommandSupport

  def initialize(agency:, actor:, supplier:, status:, lock_version:, force: false, force_reason: nil)
    @agency = agency
    @actor = actor
    @supplier = supplier
    @status = status.to_s
    @lock_version = lock_version
    @force = force
    @force_reason = force_reason
  end

  def call
    ensure_directory_actor!(@actor, @agency, :manage_supplier_directory)
    ensure_active_agency!(@agency)
    raise Error.new("Choose active or inactive.", code: :invalid) unless Supplier::STATUSES.include?(@status)

    ActiveRecord::Base.transaction do
      @agency.lock!
      @agency.reload
      ensure_active_agency!(@agency)
      @actor = @agency.agency_users.find_by(id: @actor&.id)
      ensure_directory_actor!(@actor, @agency, :manage_supplier_directory)
      supplier = @agency.suppliers.lock.find(@supplier.id)
      raise ActiveRecord::StaleObjectError.new(supplier, "lock_version") if @lock_version.nil?
      raise ActiveRecord::StaleObjectError.new(supplier, "lock_version") if supplier.lock_version != @lock_version.to_i
      return Result.new(status: :noop, record: supplier) if supplier.status == @status

      supplier.lock_version = @lock_version
      affected = if @status == "inactive"
        ensure_force_allowed! if @force
        dependency_ids = m3a_dependency_arrangement_ids(supplier)
        lock_m3a_dependencies!(dependency_ids)
        if dependency_ids.any?
          unless @force
            raise Error.new("This supplier is used by active supplier arrangement planning.", code: :dependency_exists)
          end
          ensure_force_allowed!
        end
        cascade_descendants!(supplier).merge(force_details(supplier, dependency_ids))
      else
        empty_affected
      end
      supplier.update!(status: @status)
      audit!(
        agency: @agency,
        action: @status == "inactive" ? "supplier.inactivated" : "supplier.reactivated",
        subject: supplier,
        actor: @actor,
        details: affected.merge("supplier_id" => supplier.id, "status" => @status)
      )
      Result.new(status: :updated, record: supplier)
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This record changed. Reload it and try again.", code: :conflict)
  end

  private

  def ensure_force_allowed!
    ensure_directory_actor!(@actor, @agency, :force_inactivate_supplier_with_dependencies)
    normalize_reason(@force_reason)
  end

  def force_details(supplier, dependency_ids)
    capacity_pool_ids = affected_capacity_pool_ids(supplier)
    if dependency_ids.empty?
      return {
        "forced" => false,
        "force_reason" => nil,
        "affected_supplier_arrangement_ids" => [],
        "affected_capacity_pool_ids" => capacity_pool_ids
      }
    end

    {
      "forced" => true,
      "force_reason" => normalize_reason(@force_reason),
      "affected_supplier_arrangement_ids" => dependency_ids,
      "affected_capacity_pool_ids" => capacity_pool_ids
    }
  end

  def affected_capacity_pool_ids(supplier)
    @agency.capacity_pools
      .where(supplying_supplier_id: supplier.id)
      .order(:id)
      .pluck(:id)
  end

  def m3a_dependency_arrangement_ids(supplier)
    ids = contracted_dependency_ids(supplier) | occurrence_dependency_ids(supplier)
    ids.sort
  end

  def contracted_dependency_ids(supplier)
    @agency.supplier_arrangements
      .where(contracting_supplier_id: supplier.id, status: %w[draft active])
      .pluck(:id)
  end

  def occurrence_dependency_ids(supplier)
    ServiceOccurrenceDefinition
      .joins(:service_occurrence, :supplier_arrangement)
      .joins(<<~SQL.squish)
        JOIN arrangement_item_definitions
          ON arrangement_item_definitions.supplier_arrangement_version_id = service_occurrence_definitions.supplier_arrangement_version_id
         AND arrangement_item_definitions.arrangement_item_id = service_occurrence_definitions.arrangement_item_id
      SQL
      .where(agency_id: @agency.id)
      .where(service_occurrences: { status: "planned" })
      .where(supplier_arrangements: { status: %w[draft active] })
      .where("service_occurrence_definitions.ends_on >= (CURRENT_TIMESTAMP AT TIME ZONE service_occurrence_definitions.time_zone)::date")
      .where(
        "COALESCE(service_occurrence_definitions.service_provider_id, arrangement_item_definitions.default_service_provider_id, supplier_arrangements.contracting_supplier_id) = ?",
        supplier.id
      )
      .distinct
      .pluck(:supplier_arrangement_id)
  end

  def lock_m3a_dependencies!(arrangement_ids)
    return if arrangement_ids.empty?

    departures = @agency.supplier_arrangements.where(id: arrangement_ids).distinct.order(:departure_id).pluck(:departure_id)
    @agency.departures.where(id: departures).order(:id).lock.to_a
    @agency.supplier_arrangements.where(id: arrangement_ids).order(:id).lock.to_a
  end

  def cascade_descendants!(supplier)
    affected = empty_affected
    locations = supplier.locations.order(:id).lock.to_a
    contacts = supplier.contacts.order(:id).lock.to_a

    contact_point_scopes(supplier).each_value { |scope| scope.order(:id).lock.to_a }

    contact_ids = contacts.map(&:id)
    if contact_ids.any?
      SupplierContactEmailAddress.where(agency_id: supplier.agency_id, supplier_contact_id: contact_ids)
        .order(:supplier_contact_id, :id).lock.to_a
      SupplierContactPhoneNumber.where(agency_id: supplier.agency_id, supplier_contact_id: contact_ids)
        .order(:supplier_contact_id, :id).lock.to_a
    end

    locations.each do |location|
      next if location.inactive?

      location.update!(status: "inactive")
      affected["inactivated_locations"] << { "type" => "SupplierLocation", "id" => location.id }
    end

    contacts.each do |contact|
      next if contact.inactive? && !contact.preferred?

      was_active = contact.active?
      contact.update!(status: "inactive", preferred: false)
      if was_active
        affected["inactivated_contacts"] << { "type" => "SupplierContact", "id" => contact.id }
      end
    end

    contact_point_scopes(supplier).each do |type, scope|
      scope.order(:id).each do |point|
        next if point.inactive? && !point.preferred?

        point.update!(status: "inactive", preferred: false)
        affected["inactivated_contact_points"] << { "type" => type, "id" => point.id }
      end
    end

    contacts.each do |contact|
      contact_destination_scopes(contact).each do |type, scope|
        scope.order(:id).each do |point|
          next if point.inactive? && !point.preferred?

          point.update!(status: "inactive", preferred: false)
          affected["inactivated_contact_destinations"] << { "type" => type, "id" => point.id }
        end
      end
    end

    affected
  end

  def contact_point_scopes(supplier)
    {
      "SupplierEmailAddress" => supplier.email_addresses,
      "SupplierPhoneNumber" => supplier.phone_numbers,
      "SupplierPostalAddress" => supplier.postal_addresses,
      "SupplierWebsite" => supplier.websites
    }
  end

  def contact_destination_scopes(contact)
    {
      "SupplierContactEmailAddress" => contact.email_addresses,
      "SupplierContactPhoneNumber" => contact.phone_numbers
    }
  end

  def empty_affected
    {
      "inactivated_contact_points" => [],
      "inactivated_locations" => [],
      "inactivated_contacts" => [],
      "inactivated_contact_destinations" => []
    }
  end
end
