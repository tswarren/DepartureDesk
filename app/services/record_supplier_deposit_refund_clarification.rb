# frozen_string_literal: true

class RecordSupplierDepositRefundClarification < AgencyCommand
  include SupplierTermRecordSupport

  def initialize(agency:, actor:, arrangement_item:, original_wording:, governing_wording:, refund_due_on:,
    payer: "agency", recipient: "agency", evidence_note: nil, lock_version: nil, idempotency_key: nil)
    @agency = agency
    @actor = actor
    @item = arrangement_item
    @original_wording = original_wording
    @governing_wording = governing_wording
    @payer = payer
    @recipient = recipient
    @refund_due_on = refund_due_on
    @evidence_note = evidence_note
    @lock_version = lock_version
    @idempotency_key = idempotency_key
  end

  def call
    ensure_arrangement_actor!
    safely_command do
      ActiveRecord::Base.transaction do
        lock_authorized_arrangement_agency!
        _departure, arrangement, version, item = lock_term_item!(@item)
        attrs = normalize_attrs!
        payload = attrs.merge(arrangement_item_id: item.id)
        if (replay = replay_recorded!(SupplierDepositRefundClarification, payload))
          next replay
        end

        existing = version.supplier_deposit_refund_clarifications.lock.find_by(arrangement_item_id: item.id)
        if existing
          ensure_current_lock_version!(existing, @lock_version)
          if same_clarification?(existing, attrs)
            next Result.new(status: :noop, record: existing)
          end

          existing.update!(attrs.merge(recorded_by: @actor, recorded_at: Time.current))
          audit_cost!(
            "supplier_arrangement.deposit_refund_clarification_recorded",
            arrangement, version, clarification_details(existing)
          )
          Result.new(status: :updated, record: existing)
        else
          idempotent_create!(
            command_name: self.class.name, idempotency_key: @idempotency_key,
            payload: payload, result_class: SupplierDepositRefundClarification
          ) do
            clarification = version.supplier_deposit_refund_clarifications.create!(
              term_owner(version, item).merge(attrs).merge(recorded_by: @actor, recorded_at: Time.current)
            )
            audit_cost!(
              "supplier_arrangement.deposit_refund_clarification_recorded",
              arrangement, version, clarification_details(clarification)
            )
            clarification
          end
        end
      end
    end
  end

  private

  def normalize_attrs!
    original = @original_wording.to_s.strip
    governing = @governing_wording.to_s.strip
    note = @evidence_note.to_s.strip.presence
    payer = @payer.to_s.strip
    recipient = @recipient.to_s.strip
    due_on = parse_date!(@refund_due_on)
    if original.blank? || governing.blank?
      raise Error.new("Enter the original wording and the governing wording.", code: :invalid)
    end
    if original.length > SupplierDepositRefundClarification::WORDING_LIMIT ||
        governing.length > SupplierDepositRefundClarification::WORDING_LIMIT ||
        (note && note.length > SupplierDepositRefundClarification::WORDING_LIMIT)
      raise Error.new("Clarification wording is too long.", code: :invalid)
    end
    unless payer == "agency" && recipient == "agency"
      raise Error.new("The payer and recipient must be the agency.", code: :invalid)
    end

    {
      original_wording: original,
      governing_wording: governing,
      payer: payer,
      recipient: recipient,
      refund_due_on: due_on,
      evidence_note: note
    }
  end

  def parse_date!(value)
    return value if value.is_a?(Date)

    Date.iso8601(value.to_s)
  rescue Date::Error
    raise Error.new("Enter the refund date as YYYY-MM-DD.", code: :invalid)
  end

  def same_clarification?(clarification, attrs)
    attrs.all? { |field, value| clarification.public_send(field) == value }
  end

  def clarification_details(clarification)
    {
      "supplier_deposit_refund_clarification_id" => clarification.id,
      "arrangement_item_id" => clarification.arrangement_item_id,
      "refund_due_on" => clarification.refund_due_on.iso8601
    }
  end
end
