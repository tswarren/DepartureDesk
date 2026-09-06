require "test_helper"

class PartyAlternateNameTest < ActiveSupport::TestCase
  test "rejects an unknown name kind" do
    alternate = parties(:one).alternate_names.new(
      agency: agencies(:one),
      name: "JB",
      name_kind: "nickname"
    )

    assert_not alternate.valid?
    assert alternate.errors[:name_kind].any?
  end

  test "rejects a canonical-name duplicate" do
    alternate = parties(:one).alternate_names.new(
      agency: agencies(:one),
      name: parties(:one).display_name,
      name_kind: "alias"
    )

    assert_not alternate.valid?
    assert_includes alternate.errors[:name], "matches the canonical name"
  end

  test "rejects an exact normalized duplicate among active rows" do
    parties(:one).alternate_names.create!(
      agency: agencies(:one),
      name: "Jordan B.",
      name_kind: "alias"
    )
    duplicate = parties(:one).alternate_names.new(
      agency: agencies(:one),
      name: "  jordan   b.  ",
      name_kind: "alias"
    )

    assert_not duplicate.valid?
    assert duplicate.errors[:normalized_name].any?
  end

  test "same name may belong to different parties" do
    parties(:one).alternate_names.create!(
      agency: agencies(:one),
      name: "Shared Alias",
      name_kind: "alias"
    )
    other = parties(:unlinked).alternate_names.create!(
      agency: agencies(:one),
      name: "Shared Alias",
      name_kind: "alias"
    )

    assert other.persisted?
  end

  test "original value survives normalization" do
    alternate = parties(:one).alternate_names.create!(
      agency: agencies(:one),
      name: "  Jordan B.  ",
      name_kind: "former_name"
    )

    assert_equal "Jordan B.", alternate.name
    assert_equal "jordan b.", alternate.normalized_name
  end

  test "canonical organization trading name is not stored as an active alternate" do
    alternate = parties(:organization_one).alternate_names.new(
      agency: agencies(:one),
      name: "Horizon Tours",
      name_kind: "additional_trading_name"
    )

    assert_not alternate.valid?
    assert_includes alternate.errors[:name], "matches the canonical name"
  end

  test "removal sets status to removed and does not delete the row" do
    alternate = parties(:one).alternate_names.create!(
      agency: agencies(:one),
      name: "JB",
      name_kind: "acronym"
    )

    assert_no_difference("PartyAlternateName.count") do
      RemovePartyAlternateName.new(
        agency: agencies(:one),
        actor: users(:one),
        party: parties(:one),
        alternate_name: alternate
      ).call
    end

    assert alternate.reload.removed?
    assert_not_includes parties(:one).alternate_names.visible, alternate
  end
end
