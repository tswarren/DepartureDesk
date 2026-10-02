# frozen_string_literal: true

class RecordSupplierAgreementReference < AgencyCommand
  include SupplierTermRecordSupport

  def initialize(agency:, actor:, kind:, governing_wording:, source_description:,
    arrangement_item: nil, supplier_arrangement_version: nil, scope: nil,
    original_wording: nil, supplier_reference: nil, external_reference: nil, evidence_note: nil,
    lock_version: nil, idempotency_key: nil)
    @agency = agency
    @actor = actor
    @item = arrangement_item
    @version = supplier_arrangement_version
    @scope = scope
    @kind = kind
    @governing_wording = governing_wording
    @original_wording = original_wording
    @source_description = source_description
    @supplier_reference = supplier_reference
    @external_reference = external_reference
    @evidence_note = evidence_note
    @lock_version = lock_version
    @idempotency_key = idempotency_key
  end

  def call
    ensure_arrangement_actor!
    safely_command do
      ActiveRecord::Base.transaction do
        lock_authorized_arrangement_agency!
        kind = normalize_kind!
        scope = normalize_scope!(kind)
        _departure, arrangement, version, item = lock_scope!(scope)
        ensure_unconfirmed!(version)
        attrs = normalize_attrs!(kind)
        item_id = item&.id
        payload = attrs.merge(arrangement_item_id: item_id, scope: scope)
        if (replay = replay_recorded!(SupplierAgreementReference, payload))
          next replay
        end

        existing = version.supplier_agreement_references.lock.find_by(arrangement_item_id: item_id, kind: kind)
        if existing
          ensure_current_lock_version!(existing, @lock_version)
          if same_reference?(existing, attrs)
            next Result.new(status: :noop, record: existing)
          end

          existing.update!(attrs.except(:kind).merge(recorded_by: @actor, recorded_at: Time.current))
          audit_cost!(
            "supplier_arrangement.agreement_reference_recorded",
            arrangement, version, reference_details(existing)
          )
          Result.new(status: :updated, record: existing)
        else
          reject_other_scope!(version, kind, item_id)
          idempotent_create!(
            command_name: self.class.name, idempotency_key: @idempotency_key,
            payload: payload, result_class: SupplierAgreementReference
          ) do
            reference = version.supplier_agreement_references.create!(
              term_owner(version, item).merge(attrs).merge(recorded_by: @actor, recorded_at: Time.current)
            )
            audit_cost!(
              "supplier_arrangement.agreement_reference_recorded",
              arrangement, version, reference_details(reference)
            )
            reference
          end
        end
      end
    end
  rescue ActiveRecord::StatementInvalid => error
    if error.message.include?("both Item scope and agreement-wide scope")
      raise Error.new("This term is already recorded at the other scope.", code: :invalid)
    end
    if error.message.include?("both wording and reviewed none")
      raise Error.new("This term is already reviewed as none.", code: :invalid)
    end

    raise error
  end

  private

  def normalize_kind!
    kind = @kind.to_s.strip
    unless SupplierAgreementReference::KINDS.include?(kind)
      raise Error.new("Choose an agreement reference kind.", code: :invalid)
    end

    kind
  end

  def normalize_scope!(kind)
    scope = @scope.to_s.strip
    if SupplierAgreementReference::ITEM_KINDS.include?(kind)
      if scope == "agreement"
        raise Error.new("That agreement reference stays on this Hotel stay.", code: :invalid)
      end
      raise Error.new("Choose the Arrangement Item.", code: :invalid) if @item.blank?

      "stay"
    else
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
  end

  def lock_scope!(scope)
    if scope == "agreement"
      _departure, arrangement, version = lock_explicit_version!
      [ _departure, arrangement, version, nil ]
    else
      lock_term_item!(@item)
    end
  end

  def lock_explicit_version!
    found = @agency.supplier_arrangement_versions.find(@version.is_a?(SupplierArrangementVersion) ? @version.id : @version)
    departure, arrangement, draft = lock_departure_arrangement_version!(found.supplier_arrangement)
    unless draft.id == found.id
      raise Error.new("Agreement references are recorded on the editable draft.", code: :invalid_state)
    end

    [ departure, arrangement, draft ]
  end

  def ensure_unconfirmed!(version)
    return unless SupplierConfirmation.exists?(supplier_arrangement_version_id: version.id)

    raise Error.new(
      "Agreement references are immutable after Supplier confirmation.",
      code: :invalid_state
    )
  end

  def reject_other_scope!(version, kind, item_id)
    references = version.supplier_agreement_references.where(kind: kind)
    absences = version.supplier_agreement_reference_absences.where(kind: kind)
    if item_id.nil?
      if references.where.not(arrangement_item_id: nil).exists? || absences.where.not(arrangement_item_id: nil).exists?
        raise Error.new("This term is already recorded at the other scope.", code: :invalid)
      end
      if absences.where(arrangement_item_id: nil).exists?
        raise Error.new("This term is already reviewed as none.", code: :invalid)
      end
    else
      if references.where(arrangement_item_id: nil).exists? || absences.where(arrangement_item_id: nil).exists?
        raise Error.new("This term is already recorded at the other scope.", code: :invalid)
      end
      if absences.where(arrangement_item_id: item_id).exists?
        raise Error.new("This term is already reviewed as none.", code: :invalid)
      end
    end
  end

  def normalize_attrs!(kind)
    governing = @governing_wording.to_s.strip
    original = kind == "deposit_refund" ? @original_wording.to_s.strip : @original_wording.to_s.strip.presence
    source = @source_description.to_s.strip
    supplier_reference = @supplier_reference.to_s.strip.presence
    external_reference = @external_reference.to_s.strip.presence
    note = @evidence_note.to_s.strip.presence
    if governing.blank? || source.blank?
      raise Error.new("Enter the governing wording and the Supplier source.", code: :invalid)
    end
    if kind == "deposit_refund" && original.blank?
      raise Error.new("Enter the original wording and the governing wording.", code: :invalid)
    end
    if kind != "deposit_refund" && original.present?
      raise Error.new("Original wording belongs only on a deposit-refund reference.", code: :invalid)
    end
    if [ governing, original, source, supplier_reference, external_reference, note ].compact.any? { |value|
      value.length > SupplierAgreementReference::WORDING_LIMIT
    }
      raise Error.new("Agreement reference wording is too long.", code: :invalid)
    end

    {
      kind: kind,
      governing_wording: governing,
      original_wording: kind == "deposit_refund" ? original : nil,
      source_description: source,
      supplier_reference: supplier_reference,
      external_reference: external_reference,
      evidence_note: note
    }
  end

  def same_reference?(reference, attrs)
    attrs.all? { |field, value| reference.public_send(field) == value }
  end

  def reference_details(reference)
    {
      "supplier_agreement_reference_id" => reference.id,
      "arrangement_item_id" => reference.arrangement_item_id,
      "kind" => reference.kind
    }
  end
end
