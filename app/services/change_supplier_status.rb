class ChangeSupplierStatus < AgencyCommand
  def initialize(agency:, actor:, supplier:, status:, lock_version:)
    @agency = agency
    @actor = actor
    @supplier = supplier
    @status = status.to_s
    @lock_version = lock_version
  end

  def call
    ensure_directory_actor!(@actor, @agency, :manage_supplier_directory)
    ensure_active_agency!(@agency)
    raise Error.new("Choose active or inactive.", code: :invalid) unless Supplier::STATUSES.include?(@status)

    ActiveRecord::Base.transaction do
      @agency.lock!
      supplier = @agency.suppliers.lock.find(@supplier.id)
      raise ActiveRecord::StaleObjectError.new(supplier, "lock_version") if @lock_version.nil?
      raise ActiveRecord::StaleObjectError.new(supplier, "lock_version") if supplier.lock_version != @lock_version.to_i
      return Result.new(status: :noop, record: supplier) if supplier.status == @status

      supplier.lock_version = @lock_version
      affected = @status == "inactive" ? cascade_descendants!(supplier) : empty_affected
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
