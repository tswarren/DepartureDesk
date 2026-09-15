class ChangeSupplierLocationStatus < AgencyCommand
  def initialize(agency:, actor:, supplier:, supplier_location:, status:, lock_version:)
    @agency = agency
    @actor = actor
    @supplier = supplier
    @supplier_location = supplier_location
    @status = status.to_s
    @lock_version = lock_version
  end

  def call
    ensure_directory_actor!(@actor, @agency, :manage_supplier_directory)
    ensure_active_agency!(@agency)
    raise ActiveRecord::RecordNotFound if @supplier.blank? || @supplier_location.blank?
    raise Error.new("Choose active or inactive.", code: :invalid) unless SupplierLocation::STATUSES.include?(@status)

    ActiveRecord::Base.transaction do
      @agency.lock!
      supplier = @agency.suppliers.lock.find(@supplier.id)
      location = supplier.locations.lock.find(@supplier_location.id)
      raise ActiveRecord::StaleObjectError.new(location, "lock_version") if @lock_version.nil?
      raise ActiveRecord::StaleObjectError.new(location, "lock_version") if location.lock_version != @lock_version.to_i
      return Result.new(status: :noop, record: location) if location.status == @status

      raise Error.new("That supplier is not active.", code: :invalid_state) if @status == "active" && supplier.inactive?

      location.lock_version = @lock_version
      location.update!(status: @status)
      audit!(
        agency: @agency,
        action: @status == "inactive" ? "supplier_location.inactivated" : "supplier_location.reactivated",
        subject: location,
        actor: @actor,
        details: {
          "supplier_location_id" => location.id,
          "supplier_id" => supplier.id,
          "status" => @status
        }
      )
      Result.new(status: :updated, record: location)
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This record changed. Reload it and try again.", code: :conflict)
  end
end
