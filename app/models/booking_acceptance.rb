# The client's acceptance of a booking's price and terms (BKG-39, BKG-41):
# who accepted, how and when, the terms version, the accepted total and a
# fingerprint of the price lines, and who recorded it. Email or signed
# acceptance keeps evidence, as a file (ADR 0019 amendment) or a note of
# where it is kept; phone or in person keeps a staff note. A designated
# payment counts only when the terms say so, and names the recorded client
# payment (BKG-41, D-94 (3)).
# Append-only: a change to the booking makes it stale, never edits it.
class BookingAcceptance < ApplicationRecord
  METHODS = %w[email signed phone in_person designated_payment].freeze
  METHOD_LABELS = {
    "email" => "Email", "signed" => "Signed form", "phone" => "Phone", "in_person" => "In person", "designated_payment" => "Designated payment"
  }.freeze
  ACCEPTED_BY_LIMIT = 160
  NOTE_LIMIT = 2_000
  EVIDENCE_REFERENCE_LIMIT = 300

  belongs_to :agency
  belongs_to :client_booking
  belongs_to :client_terms_version
  belongs_to :recorded_by, class_name: "AgencyUser"
  # BKG-41: a designated-payment acceptance names its payment (D-94 (3), step 8 plan question 7).
  belongs_to :client_payment, optional: true
  has_one_attached :evidence

  enum :acceptance_method, METHODS.index_by(&:itself), validate: true, prefix: :by

  def method_label = METHOD_LABELS.fetch(acceptance_method)

  # BKG-39: covers the booking only while its price lines, the inventory
  # each line's option draws on, its proposed installments (step 8 plan,
  # question 1) and its terms are the ones accepted.
  def covers?(booking)
    client_terms_version_id == booking.client_terms_version_id && lines_fingerprint == BookingAcceptance.fingerprint(booking)
  end

  def self.fingerprint(booking)
    rows = booking.price_lines.map do |line|
      [ line.choice_selection_id, line.choice_selection.option.inventory_group_id, line.booking_traveler_id, line.occupancy_position,
        line.traveler_type_id, line.amount_minor_units, line.currency ].join("|")
    end
    installments = booking.installment_proposals.map { |row| [ "installment", row.position, row.amount_minor_units, row.due_kind, row.due_on&.iso8601 ].join("|") }
    Digest::SHA256.hexdigest(([ booking.client_terms_version_id ] + rows.sort + installments.sort).join("\n"))
  end

  # Append-only; Active Storage may touch updated_at when evidence is attached.
  before_update { raise ActiveRecord::ReadOnlyRecord unless (changed - %w[updated_at]).empty? }
  before_destroy { raise ActiveRecord::ReadOnlyRecord }
end
