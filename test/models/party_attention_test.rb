require "test_helper"

class PartyAttentionTest < ActiveSupport::TestCase
  test "counts missing general-primary email or phone once" do
    party = parties(:unlinked)
    date = DirectoryDate.today(agencies(:one))
    items = PartyAttention.new(party, date:).items

    assert_equal 1, items.size
    assert_equal :missing_general_direct_contact, items.first.code
  end

  test "a general-primary postal address does not clear the direct-contact condition" do
    party = parties(:unlinked)
    contact = CreatePartyContactPoint.new(
      agency: agencies(:one),
      actor: users(:one),
      party:,
      contact_kind: "postal_address",
      attributes: {
        address_line_1: "1 Harbor Way",
        locality: "Seattle",
        administrative_region: "WA",
        postal_code: "98101",
        country_code: "US"
      }
    ).call.contact_point
    SetContactPointPrimary.new(
      agency: agencies(:one),
      actor: users(:one),
      party:,
      contact_point: contact,
      purpose: "general"
    ).call

    items = PartyAttention.new(party.reload, date: DirectoryDate.today(agencies(:one))).items
    assert_includes items.map(&:code), :missing_general_direct_contact
  end

  test "counts a suppressed current primary separately from usable general contact" do
    party = parties(:unlinked)
    general = create_email_contact!(party, address: "ops@example.com", actor: users(:one))
    SetContactPointPrimary.new(
      agency: agencies(:one),
      actor: users(:one),
      party:,
      contact_point: general,
      purpose: "general"
    ).call
    billing = create_email_contact!(party, address: "billing@example.com", actor: users(:one))
    SetContactPointPrimary.new(
      agency: agencies(:one),
      actor: users(:one),
      party:,
      contact_point: billing,
      purpose: "billing"
    ).call
    SuppressPartyContactPoint.new(
      agency: agencies(:one),
      actor: users(:one),
      party:,
      contact_point: billing,
      reason: "Mailbox retired"
    ).call

    items = PartyAttention.new(party.reload, date: DirectoryDate.today(agencies(:one))).items
    assert_equal [ :unusable_primary ], items.map(&:code)
  end

  test "counts an active supplier with no service categories" do
    party = parties(:organization_one)
    assign_supplier_role!(party, actor: users(:one))

    items = PartyAttention.new(party.reload, date: DirectoryDate.today(agencies(:one))).items
    assert_includes items.map(&:code), :missing_supplier_categories
  end
end
