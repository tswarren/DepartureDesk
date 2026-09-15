class ChangeSupplierContactStatus < AgencyCommand
  def initialize(agency:, actor:, supplier:, supplier_contact:, status:, lock_version:)
    @agency = agency
    @actor = actor
    @supplier = supplier
    @supplier_contact = supplier_contact
    @status = status.to_s
    @lock_version = lock_version
  end

  def call
    ensure_directory_actor!(@actor, @agency, :manage_supplier_directory)
    ensure_active_agency!(@agency)
    raise ActiveRecord::RecordNotFound if @supplier.blank? || @supplier_contact.blank?
    raise Error.new("Choose active or inactive.", code: :invalid) unless SupplierContact::STATUSES.include?(@status)

    ActiveRecord::Base.transaction do
      @agency.lock!
      supplier = @agency.suppliers.lock.find(@supplier.id)
      contact = supplier.contacts.lock.find(@supplier_contact.id)
      raise ActiveRecord::StaleObjectError.new(contact, "lock_version") if @lock_version.nil?
      raise ActiveRecord::StaleObjectError.new(contact, "lock_version") if contact.lock_version != @lock_version.to_i
      return Result.new(status: :noop, record: contact) if contact.status == @status

      raise Error.new("That supplier is not active.", code: :invalid_state) if @status == "active" && supplier.inactive?

      affected = []
      if @status == "inactive"
        affected = cascade_destinations!(contact)
        contact.lock_version = @lock_version
        contact.update!(status: "inactive", preferred: false)
      else
        contact.lock_version = @lock_version
        contact.update!(status: "active")
      end

      details = {
        "supplier_contact_id" => contact.id,
        "supplier_id" => supplier.id,
        "status" => @status
      }
      details["inactivated_contact_destinations"] = affected if @status == "inactive"
      audit!(
        agency: @agency,
        action: @status == "inactive" ? "supplier_contact.inactivated" : "supplier_contact.reactivated",
        subject: contact,
        actor: @actor,
        details: details
      )
      Result.new(status: :updated, record: contact)
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This record changed. Reload it and try again.", code: :conflict)
  end

  private

  def cascade_destinations!(contact)
    affected = []
    email_rows = contact.email_addresses.order(:id).lock.to_a
    phone_rows = contact.phone_numbers.order(:id).lock.to_a

    email_rows.each do |point|
      next if point.inactive? && !point.preferred?

      point.update!(status: "inactive", preferred: false)
      affected << { "type" => "SupplierContactEmailAddress", "id" => point.id }
    end
    phone_rows.each do |point|
      next if point.inactive? && !point.preferred?

      point.update!(status: "inactive", preferred: false)
      affected << { "type" => "SupplierContactPhoneNumber", "id" => point.id }
    end
    affected
  end
end
