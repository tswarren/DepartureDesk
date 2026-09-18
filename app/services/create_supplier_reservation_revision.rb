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
      booking_supplier, departure, arrangement, _version, reservation, _revision =
        lock_reservation_mutation_graph!(@reservation)
      if reservation.revisions.where(status: "planned").exists?
        raise Error.new("Abandon or request the current planned revision first.", code: :invalid_state)
      end

      source = reservation.revisions.lock.find(
        @attributes[:source_revision_id] || reservation.revisions.order(:revision_number).last.id
      )
      version = resolve_target_version!(arrangement)
      ensure_reservation_planning_state!(departure, arrangement, version, booking_supplier)
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
      if (replay = replay_reservation_idempotency(key, payload, SupplierReservationRevision))
        return replay
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
      claim_reservation_idempotency!(key, payload, revision)
      rebuild_reservation_projection_already_locked!(reservation)
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
end
