# frozen_string_literal: true

require "test_helper"

class ServiceOccurrenceEndpointScheduleTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @office = offices(:harbor_main)
    @agency.reference_sequences.find_or_create_by!(namespace: ReferenceSequence::SUPPLIER_NAMESPACE) do |sequence|
      sequence.next_value = 1
    end
    @supplier = CreateSupplier.new(
      agency: @agency, actor: @admin, kind: "organization",
      names: { display_name: "ABC Motorcoach" },
      categories: [ "ground_transportation" ]
    ).call.record
    @departure = CreateDeparture.new(
      agency: @agency, actor: @admin,
      attributes: {
        name: "Smith Family Reunion",
        starts_on: Date.new(2027, 11, 3),
        ends_on: Date.new(2027, 11, 13),
        time_zone: "America/New_York",
        operating_currency: "USD",
        responsible_office_id: @office.id,
        responsible_agency_user_id: @admin.id
      },
      current_office: @office
    ).call.record
    @arrangement = CreateSupplierArrangement.new(
      agency: @agency, actor: @admin, departure: @departure,
      idempotency_key: SecureRandom.uuid,
      attributes: { name: "ABC Motorcoach charter", contracting_supplier_id: @supplier.id }
    ).call.record
    @version = @arrangement.versions.sole
    @item = CreateArrangementItem.new(
      agency: @agency, actor: @admin, arrangement: @arrangement,
      version_lock_version: @version.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: { name: "Hotel → Port", category: "ground_transportation", default_service_provider_id: @supplier.id }
    ).call.record
  end

  test "a pickup time and endpoints persist without a drop-off time or cruise port columns" do
    occurrence = create_occurrence(
      starts_on: "2027-11-06", ends_on: "2027-11-06",
      starts_at_local: "10:00",
      origin_name: "Hilton Fort Lauderdale Marina",
      destination_name: "Port Everglades",
      time_zone: "America/New_York"
    )
    definition = @version.service_occurrence_definitions.find_by!(service_occurrence: occurrence)

    assert_equal "Hilton Fort Lauderdale Marina", definition.origin_name
    assert_equal "Port Everglades", definition.destination_name
    assert_nil definition.departure_port_name
    assert_nil definition.return_port_name
    assert_equal [ 10, 0 ], [ definition.starts_at_local.hour, definition.starts_at_local.min ]
    assert_nil definition.ends_at_local
  end

  test "a same-day drop-off before the pickup is rejected" do
    error = assert_raises(AgencyCommand::Error) do
      create_occurrence(
        starts_on: "2027-11-06", ends_on: "2027-11-06",
        starts_at_local: "10:00", ends_at_local: "09:00",
        time_zone: "America/New_York"
      )
    end
    assert_match(/End time must be at or after the start time/, error.message)
  end

  test "a cruise sailing command still rejects a one-sided local time" do
    error = assert_raises(AgencyCommand::Error) do
      CreateCruiseSailingSetup.new(
        agency: @agency, actor: @admin, departure: @departure,
        idempotency_key: SecureRandom.uuid,
        arrangement_attributes: { name: "Sailing", contracting_supplier_id: @supplier.id },
        item_attributes: { name: "Sailing" },
        occurrence_attributes: {
          name: "Sailing",
          starts_on: "2027-11-06", ends_on: "2027-11-13",
          starts_at_local: "16:00",
          time_zone: "America/New_York"
        }
      ).call
    end
    assert_match(/both a local start time and local end time/, error.message)
  end

  private

  def create_occurrence(attributes)
    CreateServiceOccurrence.new(
      agency: @agency, actor: @admin, item: @item,
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: { name: "Hotel → Port" }.merge(attributes)
    ).call.record
  end
end
