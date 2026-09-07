class PartyAttention
  Item = Struct.new(:code, :label, :path, keyword_init: true)

  def initialize(party, date:)
    @party = party
    @date = date
  end

  def items
    @items ||= [
      missing_general_direct_contact,
      unusable_primary,
      missing_supplier_categories
    ].compact
  end

  def count
    items.size
  end

  private

  def missing_general_direct_contact
    eligible = @party.contact_point_purpose_assignments.current_eligible_primaries_on(@date)
    has_email = eligible.any? { |row| row.general? && row.contact_kind == "email" }
    has_phone = eligible.any? { |row| row.general? && row.contact_kind == "phone" }
    return if has_email || has_phone

    Item.new(
      code: :missing_general_direct_contact,
      label: "No eligible general-primary email or phone",
      path: :contact
    )
  end

  def unusable_primary
    assignments = @party.contact_point_purpose_assignments
      .current_on(@date)
      .primary
      .includes(:contact_point)
    return unless assignments.any? { |row| row.contact_point.present? && !row.contact_point.eligible_destination? }

    Item.new(
      code: :unusable_primary,
      label: "A current primary destination is marked do not use or deactivated",
      path: :contact
    )
  end

  def missing_supplier_categories
    profile = @party.supplier_profile
    return unless profile&.active?
    return if profile.category_codes.any?

    Item.new(
      code: :missing_supplier_categories,
      label: "Active supplier has no service categories",
      path: :roles
    )
  end
end
