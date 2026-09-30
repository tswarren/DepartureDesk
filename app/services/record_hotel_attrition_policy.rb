# frozen_string_literal: true

class RecordHotelAttritionPolicy < AgencyCommand
  include SupplierTermRecordSupport

  def initialize(agency:, actor:, arrangement_item:, quoted_tax_rate_basis_points:, nights:, zero_utilization_rates:,
    lock_version: nil, idempotency_key: nil)
    @agency = agency
    @actor = actor
    @item = arrangement_item
    @quoted_tax_rate_basis_points = quoted_tax_rate_basis_points
    @nights = nights
    @zero_utilization_rates = zero_utilization_rates
    @lock_version = lock_version
    @idempotency_key = idempotency_key
  end

  def call
    ensure_arrangement_actor!
    safely_command do
      ActiveRecord::Base.transaction do
        lock_authorized_arrangement_agency!
        _departure, arrangement, version, item = lock_term_item!(@item)
        tax = integer_value!(@quoted_tax_rate_basis_points, "Quoted tax rate")
        unless tax.between?(0, 10_000)
          raise Error.new("Quoted tax rate must be from 0 through 10000 basis points.", code: :invalid)
        end
        nights = normalize_nights!(version, item)
        rates = normalize_rates!(version, item)
        payload = {
          arrangement_item_id: item.id, quoted_tax_rate_basis_points: tax,
          nights: nights, zero_utilization_rates: rates
        }
        if (replay = replay_recorded!(HotelAttritionPolicy, payload))
          next replay
        end

        existing = version.hotel_attrition_policies.lock.find_by(arrangement_item_id: item.id)
        if existing
          ensure_current_lock_version!(existing, @lock_version)
          if same_policy?(existing, tax, nights, rates)
            next Result.new(status: :noop, record: existing)
          end

          replace_policy!(existing, version, item, tax, nights, rates)
          audit_cost!("supplier_arrangement.hotel_attrition_policy_recorded", arrangement, version, policy_details(existing))
          Result.new(status: :updated, record: existing)
        else
          idempotent_create!(
            command_name: self.class.name, idempotency_key: @idempotency_key,
            payload: payload, result_class: HotelAttritionPolicy
          ) do
            policy = version.hotel_attrition_policies.create!(
              term_owner(version, item).merge(
                consequence: "lost_room_revenue",
                consequence_basis_points: HotelAttritionPolicy::CONSEQUENCE_BASIS_POINTS,
                quoted_tax_rate_basis_points: tax
              )
            )
            write_children!(policy, version, item, nights, rates)
            audit_cost!("supplier_arrangement.hotel_attrition_policy_recorded", arrangement, version, policy_details(policy))
            policy
          end
        end
      end
    end
  end

  private

  def normalize_nights!(version, item)
    rows = sorted_rows(@nights)
    raise Error.new("Enter at least one attrition night.", code: :invalid) if rows.empty?

    nights = rows.map do |row|
      occurrence = lock_version_occurrence!(version, item, row.fetch("service_occurrence_id"))
      minimum = integer_value!(row.fetch("minimum_utilized_room_nights"), "Minimum utilized room nights")
      raise Error.new("Minimum utilized room nights must be positive.", code: :invalid) unless minimum.positive?

      { "service_occurrence_id" => occurrence.id, "minimum_utilized_room_nights" => minimum }
    end
    ids = nights.map { |night| night["service_occurrence_id"] }
    raise Error.new("Each occurrence can have one attrition minimum.", code: :invalid) unless ids.uniq.size == ids.size

    nights.sort_by { |night| night["service_occurrence_id"] }
  end

  def normalize_rates!(version, item)
    rows = sorted_rows(@zero_utilization_rates)
    raise Error.new("Enter at least one zero-utilization rate.", code: :invalid) if rows.empty?

    rates = rows.map do |row|
      resource = lock_version_resource!(version, item, row.fetch("supplier_resource_id"))
      amount = integer_value!(row.fetch("amount_minor_units"), "Zero-utilization rate")
      raise Error.new("Zero-utilization rate cannot be negative.", code: :invalid) if amount.negative?

      { "supplier_resource_id" => resource.id, "amount_minor_units" => amount }
    end
    ids = rates.map { |rate| rate["supplier_resource_id"] }
    raise Error.new("Each resource can have one zero-utilization rate.", code: :invalid) unless ids.uniq.size == ids.size

    rates.sort_by { |rate| rate["supplier_resource_id"] }
  end

  def same_policy?(policy, tax, nights, rates)
    policy.quoted_tax_rate_basis_points == tax &&
      policy.consequence == "lost_room_revenue" &&
      policy.consequence_basis_points == HotelAttritionPolicy::CONSEQUENCE_BASIS_POINTS &&
      current_nights(policy) == nights &&
      current_rates(policy) == rates
  end

  def current_nights(policy)
    policy.hotel_attrition_nights.map { |night|
      {
        "service_occurrence_id" => night.service_occurrence_id,
        "minimum_utilized_room_nights" => night.minimum_utilized_room_nights
      }
    }.sort_by { |night| night["service_occurrence_id"] }
  end

  def current_rates(policy)
    policy.hotel_attrition_zero_utilization_rates.map { |rate|
      {
        "supplier_resource_id" => rate.supplier_resource_id,
        "amount_minor_units" => rate.amount_minor_units
      }
    }.sort_by { |rate| rate["supplier_resource_id"] }
  end

  def replace_policy!(policy, version, item, tax, nights, rates)
    policy.hotel_attrition_nights.each(&:destroy!)
    policy.hotel_attrition_zero_utilization_rates.each(&:destroy!)
    policy.update!(quoted_tax_rate_basis_points: tax)
    write_children!(policy, version, item, nights, rates)
  end

  def write_children!(policy, version, item, nights, rates)
    owner = term_owner(version, item)
    nights.each { |night| policy.hotel_attrition_nights.create!(owner.merge(night)) }
    rates.each { |rate| policy.hotel_attrition_zero_utilization_rates.create!(owner.merge(rate)) }
  end

  def policy_details(policy)
    {
      "hotel_attrition_policy_id" => policy.id,
      "arrangement_item_id" => policy.arrangement_item_id,
      "consequence" => policy.consequence,
      "quoted_tax_rate_basis_points" => policy.quoted_tax_rate_basis_points
    }
  end
end
