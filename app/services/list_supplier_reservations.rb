# frozen_string_literal: true

class ListSupplierReservations
  Outcome = Struct.new(:records, :truncated, keyword_init: true)

  LIMIT = 50
  FETCH_LIMIT = LIMIT + 1
  DEFAULT_ORDER = { created_at: :desc, id: :desc }.freeze

  def initialize(agency:, arrangement:)
    @agency = agency
    @arrangement = arrangement
  end

  def call
    rows = scope.limit(FETCH_LIMIT).to_a
    Outcome.new(records: rows.first(LIMIT), truncated: rows.size > LIMIT)
  end

  def relation_for_explain
    scope.limit(FETCH_LIMIT)
  end

  private

  def scope
    @arrangement.supplier_reservations
      .where(agency_id: @agency.id)
      .includes(:booking_supplier, projection: :current_revision)
      .order(DEFAULT_ORDER)
  end
end
