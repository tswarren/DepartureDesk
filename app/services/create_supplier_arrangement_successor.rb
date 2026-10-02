# frozen_string_literal: true

class CreateSupplierArrangementSuccessor < AgencyCommand
  include ArrangementCommandSupport

  def initialize(agency:, actor:, arrangement:, arrangement_lock_version:,
    version_lock_version:, idempotency_key:)
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @arrangement_lock_version = arrangement_lock_version
    @version_lock_version = version_lock_version
    @idempotency_key = idempotency_key
  end

  def call
    ensure_arrangement_actor!
    key = normalize_idempotency_key(@idempotency_key)

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      departure = lock_departure_for!(@arrangement.departure_id)
      arrangement = lock_arrangement_for!(@arrangement)
      predecessor = arrangement.versions.lock.find_by(id: arrangement.governing_version_id)
      payload = {
        supplier_arrangement_id: arrangement.id,
        predecessor_version_id: predecessor&.id,
        arrangement_lock_version: @arrangement_lock_version,
        version_lock_version: @version_lock_version
      }

      idempotent_create!(
        command_name: self.class.name,
        idempotency_key: key,
        payload: payload,
        result_class: SupplierArrangementVersion
      ) do
        validate_creation!(departure, arrangement, predecessor)
        ensure_current_lock_version!(arrangement, @arrangement_lock_version)
        ensure_current_lock_version!(predecessor, @version_lock_version)
        CopySupplierArrangementVersionGraph.lock!(predecessor)

        successor = arrangement.versions.create!(
          agency: @agency,
          departure: departure,
          version_number: arrangement.versions.maximum(:version_number).to_i + 1,
          copied_from: predecessor
        )
        CopySupplierArrangementVersionGraph.copy!(from: predecessor, to: successor)
        audit!(
          agency: @agency,
          action: "supplier_arrangement.successor_created",
          subject: arrangement,
          actor: @actor,
          details: {
            "supplier_arrangement_id" => arrangement.id,
            "predecessor_version_id" => predecessor.id,
            "supplier_arrangement_version_id" => successor.id,
            "version_number" => successor.version_number
          }
        )
        successor
      end
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  rescue ActiveRecord::RecordNotUnique
    raise Error.new("A successor draft already exists.", code: :conflict)
  end

  private

  def validate_creation!(departure, arrangement, predecessor)
    unless departure.active? && arrangement.active? && predecessor&.activated? &&
        !arrangement.versions.where(status: "draft").exists?
      raise Error.new(
        "Only an active arrangement without a successor draft can create a successor.",
        code: :invalid_state
      )
    end
  end
end
