require "test_helper"

class PackageConstraintsTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @other_agency = agencies(:cove)
    @actor = agency_users(:harbor_admin)
    @departure = @agency.departures.create!(
      name: "Harbor M4C Departure",
      starts_on: Date.new(2026, 6, 1),
      ends_on: Date.new(2026, 6, 8),
      time_zone: "America/New_York",
      operating_currency: "USD",
      status: "draft"
    )
    @other_departure = @agency.departures.create!(
      name: "Harbor other M4C",
      starts_on: Date.new(2026, 7, 1),
      ends_on: Date.new(2026, 7, 8),
      time_zone: "America/New_York",
      operating_currency: "USD",
      status: "draft"
    )
  end

  test "package tables have UUIDv7 defaults ownership and lock columns" do
    connection = ActiveRecord::Base.connection
    %w[packages package_versions package_inclusions].each do |table|
      columns = connection.columns(table).index_by(&:name)
      assert_equal "uuidv7()", columns.fetch("id").default_function
      assert_equal "uuid", columns.fetch("agency_id").sql_type
      assert_equal "uuid", columns.fetch("departure_id").sql_type
    end
    assert_includes connection.columns("packages").map(&:name), "lock_version"
    assert_includes connection.columns("package_versions").map(&:name), "lock_version"
    assert_includes connection.columns("service_offer_versions").map(&:name), "owning_package_version_id"
    assert_not_includes connection.columns("packages").map(&:name), "independently_sellable"
  end

  test "same-agency departure pairing is enforced" do
    other = @other_agency.departures.create!(
      name: "Cove M4C",
      starts_on: Date.new(2026, 6, 1),
      ends_on: Date.new(2026, 6, 8),
      time_zone: "UTC",
      operating_currency: "USD",
      status: "draft"
    )
    assert_raises(ActiveRecord::InvalidForeignKey) do
      Package.transaction(requires_new: true) do
        Package.insert!(package_row(departure_id: other.id))
      end
    end
  end

  test "direct SQL null to owner without inclusion is rejected" do
    package, version = create_package_graph
    offer, offer_version = create_offer_graph

    error = assert_raises(ActiveRecord::StatementInvalid) do
      ServiceOfferVersion.transaction(requires_new: true) do
        offer_version.update_column(:owning_package_version_id, version.id)
        force_deferred_constraints!
      end
    end
    assert_match(/matching inclusion/i, error.message)
    assert_nil offer.reload.editable_draft_version.owning_package_version_id
    assert_equal package.id, version.package_id
  end

  test "direct SQL null to owner with matching inclusion is allowed" do
    _package, version = create_package_graph
    offer, offer_version = create_offer_graph

    ServiceOfferVersion.transaction do
      offer_version.update_column(:owning_package_version_id, version.id)
      PackageInclusion.insert!(inclusion_row(version, offer, offer_version, origin: "adopted_draft"))
    end
    assert_equal version.id, offer_version.reload.owning_package_version_id
  end

  test "direct SQL owner to null is allowed" do
    _package, version = create_package_graph
    offer, offer_version = create_offer_graph
    ServiceOfferVersion.transaction do
      offer_version.update_column(:owning_package_version_id, version.id)
      PackageInclusion.insert!(inclusion_row(version, offer, offer_version, origin: "adopted_draft"))
    end

    offer_version.update_column(:owning_package_version_id, nil)
    assert_nil offer_version.reload.owning_package_version_id
  end

  test "direct SQL owner to different owner is rejected even with both inclusions" do
    _package_a, version_a = create_package_graph
    _package_b, version_b = create_package_graph(name: "Second package")
    offer, offer_version = create_offer_graph
    ServiceOfferVersion.transaction do
      offer_version.update_column(:owning_package_version_id, version_a.id)
      PackageInclusion.insert!(inclusion_row(version_a, offer, offer_version, origin: "adopted_draft"))
    end
    error = assert_raises(ActiveRecord::StatementInvalid) do
      ServiceOfferVersion.transaction(requires_new: true) do
        offer_version.update_column(:owning_package_version_id, version_b.id)
      end
    end
    assert_match(/cannot be reassigned/i, error.message)
    assert_equal version_a.id, offer_version.reload.owning_package_version_id
  end

  test "cross-departure ownership is rejected" do
    _package, version = create_package_graph
    offer = ServiceOffer.create!(agency: @agency, departure: @other_departure, name: "Other dep offer")
    offer_version = offer.versions.create!(
      agency: @agency, departure: @other_departure, version_number: 1, status: "draft"
    )

    error = assert_raises(ActiveRecord::StatementInvalid) do
      ServiceOfferVersion.transaction(requires_new: true) do
        offer_version.update_column(:owning_package_version_id, version.id)
      end
    end
    assert_match(/foreign key|share agency and departure/i, error.message)
  end

  test "one editable draft cannot appear in two package drafts" do
    _package, version = create_package_graph
    _other, other_version = create_package_graph(name: "Twin")
    offer, offer_version = create_offer_graph
    ServiceOfferVersion.transaction do
      offer_version.update_column(:owning_package_version_id, version.id)
      PackageInclusion.insert!(inclusion_row(version, offer, offer_version, origin: "adopted_draft"))
    end

    error = assert_raises(ActiveRecord::StatementInvalid) do
      ServiceOfferVersion.transaction(requires_new: true) do
        offer_version.update_column(:owning_package_version_id, other_version.id)
        PackageInclusion.insert!(inclusion_row(other_version, offer, offer_version, origin: "adopted_draft"))
      end
    end
    assert_match(/cannot be reassigned|one_draft_service|duplicate key/i, error.message)
  end

  test "abandon freezes inclusions" do
    package, version = create_package_graph
    offer, offer_version = create_offer_graph
    ServiceOfferVersion.transaction do
      offer_version.update_column(:owning_package_version_id, version.id)
      PackageInclusion.insert!(inclusion_row(version, offer, offer_version, origin: "inline_create"))
    end
    version.update!(status: "abandoned", abandoned_at: Time.current, abandoned_reason: "Stop")

    error = assert_raises(ActiveRecord::StatementInvalid) do
      PackageInclusion.transaction(requires_new: true) do
        version.inclusions.first.update_column(:placement, "optional")
      end
    end
    assert_match(/immutable after leaving draft/i, error.message)
    assert package.present?
  end

  private

  def create_package_graph(name: "Draft package")
    package = Package.create!(agency: @agency, departure: @departure, name: name)
    version = package.versions.create!(
      agency: @agency, departure: @departure, version_number: 1, status: "draft"
    )
    [ package, version ]
  end

  def create_offer_graph
    offer = ServiceOffer.create!(agency: @agency, departure: @departure, name: "Draft offer")
    version = offer.versions.create!(
      agency: @agency, departure: @departure, version_number: 1, status: "draft"
    )
    [ offer, version ]
  end

  def package_row(**attrs)
    {
      id: SecureRandom.uuid_v7,
      agency_id: @agency.id,
      departure_id: @departure.id,
      name: "Inserted package",
      lock_version: 0,
      created_at: Time.current,
      updated_at: Time.current
    }.merge(attrs)
  end

  def inclusion_row(package_version, offer, offer_version, origin:)
    {
      id: SecureRandom.uuid_v7,
      agency_id: @agency.id,
      departure_id: @departure.id,
      package_id: package_version.package_id,
      package_version_id: package_version.id,
      service_offer_id: offer.id,
      service_offer_version_id: offer_version.id,
      placement: "included",
      origin: origin,
      position: 1,
      created_at: Time.current,
      updated_at: Time.current
    }
  end

  def force_deferred_constraints!
    ActiveRecord::Base.connection.execute("SET CONSTRAINTS ALL IMMEDIATE")
  end
end
