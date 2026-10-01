# frozen_string_literal: true

class RecordSupplierAgreementReference < AgencyCommand
  include SupplierTermRecordSupport

  def initialize(agency:, actor:, arrangement_item:, kind:, governing_wording:, source_description:,
    original_wording: nil, supplier_reference: nil, external_reference: nil, evidence_note: nil,
    lock_version: nil, idempotency_key: nil)
    @agency = agency
    @actor = actor
    @item = arrangement_item
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
        raise Error.new("Choose the Arrangement Item.", code: :invalid) if @item.blank?

        _departure, arrangement, version, item = lock_term_item!(@item)
        attrs = normalize_attrs!(kind)
        payload = attrs.merge(arrangement_item_id: item.id)
        if (replay = replay_recorded!(SupplierAgreementReference, payload))
          next replay
        end

        existing = version.supplier_agreement_references.lock.find_by(arrangement_item_id: item.id, kind: kind)
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
  end

  private

  def normalize_kind!
    kind = @kind.to_s.strip
    unless SupplierAgreementReference::KINDS.include?(kind)
      raise Error.new("Choose an agreement reference kind.", code: :invalid)
    end
    unless SupplierAgreementReference::ITEM_KINDS.include?(kind)
      raise Error.new("That agreement reference is not recorded in this workflow.", code: :invalid)
    end

    kind
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
