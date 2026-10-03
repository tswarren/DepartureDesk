# frozen_string_literal: true

class RecordSupplierAgreementReferenceAbsence < AgencyCommand
  include SupplierTermRecordSupport

  def initialize(agency:, actor:, kind:, scope:, arrangement_item: nil,
    supplier_arrangement_version: nil, idempotency_key: nil)
    @agency = agency
    @actor = actor
    @kind = kind
    @scope = scope
    @item = arrangement_item
    @version = supplier_arrangement_version
    @idempotency_key = idempotency_key
  end

  def call
    ensure_arrangement_actor!
    safely_command do
      ActiveRecord::Base.transaction do
        lock_authorized_arrangement_agency!
        kind = normalize_kind!
        scope = normalize_scope!
        _departure, arrangement, version, item = lock_scope!(scope)
        ensure_unconfirmed!(version)
        item_id = item&.id
        payload = { kind: kind, arrangement_item_id: item_id, scope: scope }
        if (replay = replay_recorded!(SupplierAgreementReferenceAbsence, payload))
          next replay
        end

        existing = version.supplier_agreement_reference_absences.lock.find_by(arrangement_item_id: item_id, kind: kind)
        if existing
          next Result.new(status: :noop, record: existing)
        end

        reject_conflicts!(version, kind, item_id)
        idempotent_create!(
          command_name: self.class.name, idempotency_key: @idempotency_key,
          payload: payload, result_class: SupplierAgreementReferenceAbsence
        ) do
          absence = version.supplier_agreement_reference_absences.create!(
            term_owner(version, item).merge(kind: kind, recorded_by: @actor, recorded_at: Time.current)
          )
          audit_cost!(
            "supplier_arrangement.agreement_reference_absence_recorded",
            arrangement, version, absence_details(absence)
          )
          absence
        end
      end
    end
  rescue ActiveRecord::StatementInvalid => error
    translate_scope_conflict!(error)
  end

  private

  def normalize_kind!
    kind = @kind.to_s.strip
    unless SupplierAgreementReference::HOTEL_KINDS.include?(kind)
      raise Error.new("Choose an agreement reference kind.", code: :invalid)
    end

    kind
  end

  def normalize_scope!
    scope = @scope.to_s.strip
    if SupplierAgreementReference::ITEM_KINDS.include?(@kind.to_s.strip)
      if scope == "agreement"
        raise Error.new("That agreement reference stays on this Hotel stay.", code: :invalid)
      end
      raise Error.new("Choose the Arrangement Item.", code: :invalid) if @item.blank?

      return "stay"
    end

    case scope
    when "stay"
      raise Error.new("Choose the Arrangement Item.", code: :invalid) if @item.blank?

      "stay"
    when "agreement"
      raise Error.new("Choose the Supplier agreement version.", code: :invalid) if @version.blank?

      "agreement"
    else
      raise Error.new(
        "Choose whether this term covers this Hotel stay or the entire Supplier agreement.",
        code: :invalid
      )
    end
  end

  def lock_scope!(scope)
    if scope == "agreement"
      found = @agency.supplier_arrangement_versions.find(@version.is_a?(SupplierArrangementVersion) ? @version.id : @version)
      departure, arrangement, draft = lock_departure_arrangement_version!(found.supplier_arrangement)
      unless draft.id == found.id
        raise Error.new("Agreement references are recorded on the editable draft.", code: :invalid_state)
      end

      [ departure, arrangement, draft, nil ]
    else
      lock_term_item!(@item)
    end
  end

  def ensure_unconfirmed!(version)
    return unless SupplierConfirmation.exists?(supplier_arrangement_version_id: version.id)

    raise Error.new(
      "Agreement references are immutable after Supplier confirmation.",
      code: :invalid_state
    )
  end

  def reject_conflicts!(version, kind, item_id)
    references = version.supplier_agreement_references.where(kind: kind)
    absences = version.supplier_agreement_reference_absences.where(kind: kind)
    if item_id.nil?
      if references.where.not(arrangement_item_id: nil).exists? || absences.where.not(arrangement_item_id: nil).exists?
        raise Error.new("This term is already recorded at the other scope.", code: :invalid)
      end
      if references.where(arrangement_item_id: nil).exists?
        raise Error.new("This term already has governing wording.", code: :invalid)
      end
    else
      if references.where(arrangement_item_id: nil).exists? || absences.where(arrangement_item_id: nil).exists?
        raise Error.new("This term is already recorded at the other scope.", code: :invalid)
      end
      if references.where(arrangement_item_id: item_id).exists?
        raise Error.new("This term already has governing wording.", code: :invalid)
      end
    end
  end

  def absence_details(absence)
    {
      "supplier_agreement_reference_absence_id" => absence.id,
      "arrangement_item_id" => absence.arrangement_item_id,
      "kind" => absence.kind
    }
  end

  def translate_scope_conflict!(error)
    if error.message.include?("both Item scope and agreement-wide scope")
      raise Error.new("This term is already recorded at the other scope.", code: :invalid)
    end
    if error.message.include?("both wording and reviewed none")
      raise Error.new("This term already has governing wording.", code: :invalid)
    end

    raise error
  end
end
