# frozen_string_literal: true

class CreateSupplierDepositBasis < AgencyCommand
  include SupplierTermRecordSupport

  def initialize(agency:, actor:, arrangement_item:, currency:, basis_amount_minor_units:, entries:, shares:,
    lock_version: nil, idempotency_key: nil)
    @agency = agency
    @actor = actor
    @item = arrangement_item
    @currency = currency
    @basis_amount_minor_units = basis_amount_minor_units
    @entries = entries
    @shares = shares
    @lock_version = lock_version
    @idempotency_key = idempotency_key
  end

  def call
    ensure_arrangement_actor!
    safely_command do
      ActiveRecord::Base.transaction do
        lock_authorized_arrangement_agency!
        departure, arrangement, version, item = lock_term_item!(@item)
        currency = normalize_currency(@currency, departure)
        amount = integer_value!(@basis_amount_minor_units, "Basis amount")
        raise Error.new("Basis amount cannot be negative.", code: :invalid) if amount.negative?

        lines = normalize_entries!(version, item, amount)
        links = normalize_shares!(version, currency, amount)
        payload = {
          arrangement_item_id: item.id, currency: currency, basis_amount_minor_units: amount,
          entries: lines, shares: links
        }
        if (replay = replay_recorded!(SupplierDepositBasis, payload))
          next replay
        end

        existing = version.supplier_deposit_bases.lock.find_by(arrangement_item_id: item.id)
        if existing
          ensure_current_lock_version!(existing, @lock_version)
          if same_basis?(existing, currency, amount, lines, links)
            next Result.new(status: :noop, record: existing)
          end

          replace_basis!(existing, version, item, currency, amount, lines, links)
          audit_cost!("supplier_arrangement.deposit_basis_recorded", arrangement, version, basis_details(existing))
          Result.new(status: :updated, record: existing)
        else
          idempotent_create!(
            command_name: self.class.name, idempotency_key: @idempotency_key,
            payload: payload, result_class: SupplierDepositBasis
          ) do
            basis = version.supplier_deposit_bases.create!(
              term_owner(version, item).merge(
                basis_kind: "original_contracted_room_revenue",
                currency: currency,
                basis_amount_minor_units: amount
              )
            )
            write_children!(basis, version, item, lines, links)
            audit_cost!("supplier_arrangement.deposit_basis_recorded", arrangement, version, basis_details(basis))
            basis
          end
        end
      end
    end
  end

  private

  def normalize_entries!(version, item, amount)
    rows = sorted_rows(@entries)
    raise Error.new("Enter at least one deposit basis line.", code: :invalid) if rows.empty?

    lines = rows.map do |row|
      occurrence = lock_version_occurrence!(version, item, row.fetch("service_occurrence_id"))
      resource = lock_version_resource!(version, item, row.fetch("supplier_resource_id"))
      quantity = integer_value!(row.fetch("agreed_quantity"), "Agreed quantity")
      rate = integer_value!(row.fetch("agreed_unit_rate_minor_units"), "Agreed rate")
      extended = integer_value!(row.fetch("extended_amount_minor_units"), "Extended amount")
      raise Error.new("Agreed quantity must be positive.", code: :invalid) unless quantity.positive?
      raise Error.new("Agreed rate cannot be negative.", code: :invalid) if rate.negative?
      unless quantity * rate == extended
        raise Error.new("Each deposit basis line must extend quantity times rate.", code: :invalid)
      end

      {
        "service_occurrence_id" => occurrence.id,
        "supplier_resource_id" => resource.id,
        "agreed_quantity" => quantity,
        "agreed_unit_rate_minor_units" => rate,
        "extended_amount_minor_units" => extended
      }
    end
    unless lines.map { |line| [ line["service_occurrence_id"], line["supplier_resource_id"] ] }.uniq.size == lines.size
      raise Error.new("Each occurrence and resource can appear once on a deposit basis.", code: :invalid)
    end
    unless lines.sum { |line| line["extended_amount_minor_units"] } == amount
      raise Error.new("Deposit basis lines must add up to the basis amount.", code: :invalid)
    end

    lines.sort_by { |line| [ line["service_occurrence_id"], line["supplier_resource_id"] ] }
  end

  def normalize_shares!(version, currency, amount)
    rows = sorted_rows(@shares)
    raise Error.new("Enter the deposit basis shares.", code: :invalid) if rows.empty?

    links = rows.map do |row|
      requirement = version.supplier_deposit_requirement_definitions.lock.find(
        row.fetch("supplier_deposit_requirement_definition_id")
      )
      points = integer_value!(row.fetch("share_basis_points"), "Share")
      unless requirement.fixed_amount? && requirement.percentage.nil? && requirement.currency == currency
        raise Error.new("Deposit basis shares attach only to fixed requirements in the basis currency.", code: :invalid)
      end
      unless points.positive? && points <= 10_000 && amount * points == requirement.fixed_amount_minor_units * 10_000
        raise Error.new("Each deposit share must reproduce its fixed amount exactly.", code: :invalid)
      end

      {
        "supplier_deposit_requirement_definition_id" => requirement.id,
        "share_basis_points" => points
      }
    end
    ids = links.map { |link| link["supplier_deposit_requirement_definition_id"] }
    raise Error.new("Each deposit requirement can have one basis share.", code: :invalid) unless ids.uniq.size == ids.size
    unless links.sum { |link| link["share_basis_points"] } == 10_000
      raise Error.new("Deposit basis shares must total 10000 basis points.", code: :invalid)
    end

    links.sort_by { |link| link["supplier_deposit_requirement_definition_id"] }
  end

  def same_basis?(basis, currency, amount, lines, links)
    basis.currency == currency &&
      basis.basis_amount_minor_units == amount &&
      basis.basis_kind == "original_contracted_room_revenue" &&
      current_lines(basis) == lines &&
      current_links(basis) == links
  end

  def current_lines(basis)
    basis.supplier_deposit_basis_entries.map { |entry|
      {
        "service_occurrence_id" => entry.service_occurrence_id,
        "supplier_resource_id" => entry.supplier_resource_id,
        "agreed_quantity" => entry.agreed_quantity,
        "agreed_unit_rate_minor_units" => entry.agreed_unit_rate_minor_units,
        "extended_amount_minor_units" => entry.extended_amount_minor_units
      }
    }.sort_by { |line| [ line["service_occurrence_id"], line["supplier_resource_id"] ] }
  end

  def current_links(basis)
    basis.supplier_deposit_basis_shares.map { |share|
      {
        "supplier_deposit_requirement_definition_id" => share.supplier_deposit_requirement_definition_id,
        "share_basis_points" => share.share_basis_points
      }
    }.sort_by { |link| link["supplier_deposit_requirement_definition_id"] }
  end

  def replace_basis!(basis, version, item, currency, amount, lines, links)
    basis.supplier_deposit_basis_entries.each(&:destroy!)
    basis.supplier_deposit_basis_shares.each(&:destroy!)
    basis.update!(currency: currency, basis_amount_minor_units: amount)
    write_children!(basis, version, item, lines, links)
  end

  def write_children!(basis, version, item, lines, links)
    owner = term_owner(version, item)
    lines.each do |line|
      basis.supplier_deposit_basis_entries.create!(owner.merge(line))
    end
    links.each do |link|
      basis.supplier_deposit_basis_shares.create!(owner.merge(link))
    end
  end

  def basis_details(basis)
    {
      "supplier_deposit_basis_id" => basis.id,
      "arrangement_item_id" => basis.arrangement_item_id,
      "basis_amount_minor_units" => basis.basis_amount_minor_units,
      "currency" => basis.currency
    }
  end
end
