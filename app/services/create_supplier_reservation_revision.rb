class CreateSupplierReservationRevision < AgencyCommand
  include ReservationCommandSupport

  def initialize(agency:, actor:, reservation:, attributes:, idempotency_key:)
    @agency = agency
    @actor = actor
    @reservation = reservation
    @attributes = attributes.to_h.with_indifferent_access
    @idempotency_key = idempotency_key || @attributes.delete(:idempotency_key)
  end

  def call
    ensure_arrangement_actor!
    key = normalize_idempotency_key(@idempotency_key)

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      reservation = @agency.supplier_reservations.lock.find(@reservation.id)
      arrangement = @agency.supplier_arrangements.lock.find(reservation.supplier_arrangement_id)
      departure = @agency.departures.lock.find(reservation.departure_id)
      lock_idempotency_slot!(self.class.name, key)
      if (existing = existing_idempotency(key))
        return Result.new(status: :replayed, record: SupplierReservationRevision.find(existing.result_record_id))
      end
      if reservation.revisions.where(status: "planned").exists?
        raise Error.new("Abandon or request the current planned revision first.", code: :invalid_state)
      end

      source = reservation.revisions.lock.find(@attributes[:source_revision_id] || reservation.revisions.order(:revision_number).last.id)
      version = resolve_target_version!(arrangement)
      ensure_reservation_planning_state!(departure, arrangement, version, reservation.booking_supplier)
      scopes = if @attributes[:scopes].present?
        normalize_scopes!(arrangement, version, @attributes[:scopes])
      else
        source.scopes.order(:position, :id).map do |scope|
          scope.attributes.symbolize_keys.slice(
            :position, :target_kind, :arrangement_item_id, :service_occurrence_id,
            :supplier_resource_id, :capacity_pool_id, :label, :requested_quantity, :quantity_basis
          )
        end
      end
      payload = {
        reservation_id: reservation.id,
        source_revision_id: source.id,
        version_id: version.id,
        scopes: scopes
      }
      if (existing = existing_idempotency(key))
        unless existing.payload_digest == payload_digest(payload)
          raise Error.new("That idempotency key was already used for different input.", code: :conflict)
        end
        return Result.new(status: :replayed, record: SupplierReservationRevision.find(existing.result_record_id))
      end

      revision = reservation.revisions.create!(
        reservation_owner(reservation, version).merge(
          revision_number: reservation.revisions.maximum(:revision_number).to_i + 1,
          status: "planned",
          actor: @actor
        )
      )
      scopes.each do |attrs|
        revision.scopes.create!(reservation_owner(reservation, version).merge(attrs))
      end
      AgencyCommandIdempotencyKey.create!(
        agency: @agency,
        command_name: self.class.name,
        idempotency_key: key,
        payload_digest: payload_digest(payload),
        result_record_type: SupplierReservationRevision.name,
        result_record_id: revision.id
      )
      RebuildSupplierReservationProjection.new(
        agency: @agency, actor: @actor, reservation: reservation
      ).call
      audit!(
        agency: @agency, action: "supplier_reservation.revised", subject: reservation, actor: @actor,
        details: {
          "supplier_reservation_id" => reservation.id,
          "supplier_reservation_revision_id" => revision.id,
          "source_revision_id" => source.id
        }
      )
      Result.new(status: :created, record: revision)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  private

  def resolve_target_version!(arrangement)
    explicit = @attributes[:supplier_arrangement_version_id]
    if explicit.present?
      version = arrangement.versions.lock.find(explicit)
      return version if version.activated? || version.draft?

      raise Error.new("Choose the current activated version or the sole successor draft.", code: :invalid)
    end
    draft = arrangement.versions.lock.find_by(status: "draft")
    return draft if draft
    return arrangement.governing_version.lock! if arrangement.governing_version

    raise Error.new("No editable arrangement version is available for a new reservation revision.", code: :invalid_state)
  end

  def existing_idempotency(key)
    @agency.agency_command_idempotency_keys.where(
      command_name: self.class.name, idempotency_key: key
    ).lock.first
  end
end
