class SetPreferredSupplierContact < AgencyCommand
  def initialize(agency:, actor:, supplier:, supplier_contact:, preferred:, lock_version:)
    @agency = agency
    @actor = actor
    @supplier = supplier
    @supplier_contact = supplier_contact
    @preferred = preferred
    @lock_version = lock_version
  end

  def call
    ensure_directory_actor!(@actor, @agency, :manage_supplier_directory)
    ensure_active_agency!(@agency)
    raise ActiveRecord::RecordNotFound if @supplier.blank? || @supplier_contact.blank?
    raise Error.new("This record changed. Reload it and try again.", code: :conflict) if @lock_version.nil?

    preferred = ActiveModel::Type::Boolean.new.cast(@preferred)

    ActiveRecord::Base.transaction do
      @agency.lock!
      supplier = @agency.suppliers.lock.find(@supplier.id)
      contacts = supplier.contacts.active.order(:id).lock.to_a
      contact = contacts.find { |row| row.id == @supplier_contact.id } || raise(ActiveRecord::RecordNotFound)
      raise ActiveRecord::StaleObjectError.new(contact, "lock_version") if contact.lock_version != @lock_version.to_i
      return Result.new(status: :noop, record: contact) if contact.preferred? == preferred

      if preferred
        raise Error.new("That supplier is not active.", code: :invalid_state) unless supplier.active?
        raise Error.new("Only an active record can be preferred.", code: :invalid_state) unless contact.active?

        contacts.each do |row|
          next unless row.preferred? && row.id != contact.id

          row.update!(preferred: false)
        end
      end

      contact.lock_version = @lock_version
      contact.update!(preferred: preferred)
      audit!(
        agency: @agency,
        action: "supplier_contact.preferred_changed",
        subject: contact,
        actor: @actor,
        details: {
          "supplier_contact_id" => contact.id,
          "supplier_id" => supplier.id,
          "preferred" => preferred
        }
      )
      Result.new(status: :updated, record: contact)
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This record changed. Reload it and try again.", code: :conflict)
  end
end
