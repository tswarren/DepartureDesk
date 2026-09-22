# frozen_string_literal: true

# Shared Cruise Supplier-rate matrix vocabulary for Slice 2A.2R.
# Rate profiles are columns; component rows are charges/credits; cells compile to
# generic SupplierCostComponent records. No Cruise-specific persistence.
module CruiseSupplierRateSupport
  PARTICIPANT_CATEGORY_LABEL = "Traveler"
  ADULT_CATEGORY_LABEL = "Adult"
  COMMISSION_LABEL = "Expected commission"
  COMMISSION_METHODS = %w[not_provided dollar percentage].freeze
  OVERLAP_RESOLUTIONS = %w[scope_existing_to_adult keep_every_traveler edit_profiles].freeze
  CUSTOM_ROW_ROLES = %w[supplier_charge supplier_credit].freeze
  PROFILE_CATEGORY_SEPARATOR = "__"
  CUSTOM_ROW_KEY_PATTERN = /\A[a-z][a-z0-9_]{0,62}\z/

  STATIC_ROWS = {
    base_fare: { label: "Base Fare", economic_role: "supplier_charge" },
    nccf: { label: "NCCF", economic_role: "supplier_charge" },
    taxes_fees: { label: "Taxes & Fees", economic_role: "supplier_charge" },
    discount: { label: "Discount", economic_role: "supplier_credit" }
  }.freeze

  PROFILE_FAMILIES = {
    first_second: {
      label: "First/Second",
      quantity_basis: "occupancy_positions",
      occupancy_position_from: 1,
      occupancy_position_to: 2,
      allows_participant_category: true
    },
    additional: {
      label: "Additional",
      quantity_basis: "occupancy_positions",
      occupancy_position_from: 3,
      occupancy_position_to: nil,
      allows_participant_category: true
    },
    bounded_positions: {
      label: "Bounded positions",
      quantity_basis: "occupancy_positions",
      staff_supplied_positions: true,
      allows_participant_category: true
    },
    every_traveler: {
      label: "Every Traveler",
      quantity_basis: "persons",
      occupancy_position_from: nil,
      occupancy_position_to: nil,
      allows_participant_category: true
    },
    every_cabin: {
      label: "Every Cabin",
      quantity_basis: "resource_units",
      occupancy_position_from: nil,
      occupancy_position_to: nil,
      allows_participant_category: false
    },
    single_supplement: {
      label: "Single Supplement",
      quantity_basis: "single_occupancy_units",
      occupancy_position_from: nil,
      occupancy_position_to: nil,
      allows_participant_category: false
    }
  }.freeze

  # Shipped 2A.2 fixed-form labels → matrix cells (row_key, profile_key).
  LEGACY_LABEL_TO_CELL = {
    "First/second traveler fare" => %i[base_fare first_second],
    "Additional traveler fare" => %i[base_fare additional],
    "Single occupancy supplement" => %i[base_fare single_supplement],
    "NCCF" => %i[nccf every_traveler],
    "First/second traveler discount" => %i[discount first_second],
    "Additional traveler discount" => %i[discount additional],
    "Taxes, fees, and port charges" => %i[taxes_fees every_traveler]
  }.freeze

  LEGACY_ONLY_LABELS = (
    LEGACY_LABEL_TO_CELL.keys - STATIC_ROWS.values.map { |spec| spec.fetch(:label) }
  ).freeze

  OCCUPANCY_PROFILE_SPECS = {
    single: { label: "Single occupancy", positions: 1 },
    double: { label: "Double occupancy", positions: 2 },
    triple: { label: "Triple occupancy", positions: 3 }
  }.freeze

  module_function

  def static_row_keys
    STATIC_ROWS.keys
  end

  def profile_family_keys
    PROFILE_FAMILIES.keys
  end

  def static_row_label(key)
    STATIC_ROWS.fetch(key.to_sym).fetch(:label)
  end

  def static_row_role(key)
    STATIC_ROWS.fetch(key.to_sym).fetch(:economic_role)
  end

  def normalize_row_label(label)
    text = label.to_s.strip
    STATIC_ROWS.each_value do |spec|
      return spec.fetch(:label) if spec.fetch(:label).casecmp?(text)
    end
    text
  end

  def static_row_key_for_label(label)
    normalized = normalize_row_label(label)
    STATIC_ROWS.each do |key, spec|
      return key if spec.fetch(:label) == normalized
    end
    nil
  end

  def encode_profile_key(family, category: nil, occupancy_position_from: nil, occupancy_position_to: nil)
    family_key = family.to_sym
    raise ArgumentError, "Unknown profile family" unless PROFILE_FAMILIES.key?(family_key)

    spec = PROFILE_FAMILIES.fetch(family_key)
    base = if spec[:staff_supplied_positions]
      from = occupancy_position_from.to_i
      raise ArgumentError, "Bounded positions require a starting position" if from < 1

      to = occupancy_position_to.nil? || occupancy_position_to.to_s.strip.empty? ? nil : occupancy_position_to.to_i
      raise ArgumentError, "Ending position must be at or after the start" if to && to < from

      to ? "bounded_#{from}_#{to}" : "bounded_#{from}"
    else
      family_key.to_s
    end

    text = category.to_s.strip
    return base if text.empty?

    "#{base}#{PROFILE_CATEGORY_SEPARATOR}#{text}"
  end

  def decode_profile_key(key)
    text = key.to_s
    category = nil
    if text.include?(PROFILE_CATEGORY_SEPARATOR)
      text, category = text.split(PROFILE_CATEGORY_SEPARATOR, 2)
      category = category.presence
    end

    if (match = text.match(/\Abounded_(\d+)(?:_(\d+))?\z/))
      {
        family: :bounded_positions,
        category: category,
        occupancy_position_from: match[1].to_i,
        occupancy_position_to: match[2]&.to_i
      }
    else
      {
        family: text.to_sym,
        category: category,
        occupancy_position_from: PROFILE_FAMILIES.dig(text.to_sym, :occupancy_position_from),
        occupancy_position_to: PROFILE_FAMILIES.dig(text.to_sym, :occupancy_position_to)
      }
    end
  end

  def profile_display_label(profile_key)
    decoded = decode_profile_key(profile_key)
    family = PROFILE_FAMILIES[decoded[:family]]
    return profile_key.to_s unless family

    base = if decoded[:family] == :bounded_positions
      from = decoded[:occupancy_position_from]
      to = decoded[:occupancy_position_to]
      to ? "Positions #{from}–#{to}" : "Position #{from}+"
    else
      family.fetch(:label)
    end
    decoded[:category].present? ? "#{base} · #{decoded[:category]}" : base
  end

  def profile_key_for_component(component, categories_by_id: nil)
    category_label = nil
    if component.participant_category_id.present?
      category = categories_by_id&.[](component.participant_category_id) || component.participant_category
      category_label = category&.label
      return nil if category_label.blank?
    end

    PROFILE_FAMILIES.each do |key, spec|
      next if spec[:staff_supplied_positions]
      next unless component.quantity_basis == spec.fetch(:quantity_basis)
      next unless component.occupancy_position_from == spec[:occupancy_position_from]
      next unless component.occupancy_position_to == spec[:occupancy_position_to]

      return encode_profile_key(key, category: category_label)
    end

    if component.quantity_basis == "occupancy_positions" && component.occupancy_position_from.present?
      return encode_profile_key(
        :bounded_positions,
        category: category_label,
        occupancy_position_from: component.occupancy_position_from,
        occupancy_position_to: component.occupancy_position_to
      )
    end

    nil
  end

  def cell_key(row_key, profile_key)
    "#{row_key}:#{profile_key}"
  end

  def parse_cell_key(key)
    row_key, profile_key = key.to_s.split(":", 2)
    [ row_key&.to_sym, profile_key ]
  end

  def slugify_custom_row_key(label)
    slug = label.to_s.strip.downcase.gsub(/[^a-z0-9]+/, "_").gsub(/\A_+|_+\z/, "")
    slug = "custom" if slug.empty?
    slug = "custom_#{slug}" if STATIC_ROWS.key?(slug.to_sym)
    slug[0, 63]
  end

  def occupancy_keys_for_maximum(maximum_occupancy)
    max = maximum_occupancy.to_i
    keys = []
    keys << :single if max >= 1
    keys << :double if max >= 2
    keys << :triple if max >= 3
    keys
  end

  def position_ranges_overlap?(left, right)
    left_family = left.is_a?(Hash) ? left[:family].to_sym : left.to_sym
    right_family = right.is_a?(Hash) ? right[:family].to_sym : right.to_sym
    spec_a = PROFILE_FAMILIES[left_family]
    spec_b = PROFILE_FAMILIES[right_family]
    return false unless spec_a && spec_b
    return false unless spec_a.fetch(:allows_participant_category) && spec_b.fetch(:allows_participant_category)
    return false unless spec_a.fetch(:quantity_basis) == "occupancy_positions"
    return false unless spec_b.fetch(:quantity_basis) == "occupancy_positions"

    from_a = left.is_a?(Hash) ? (left[:occupancy_position_from] || spec_a[:occupancy_position_from]) : spec_a[:occupancy_position_from]
    to_a = if left.is_a?(Hash) && left.key?(:occupancy_position_to)
      left[:occupancy_position_to]
    else
      spec_a[:occupancy_position_to]
    end
    from_b = right.is_a?(Hash) ? (right[:occupancy_position_from] || spec_b[:occupancy_position_from]) : spec_b[:occupancy_position_from]
    to_b = if right.is_a?(Hash) && right.key?(:occupancy_position_to)
      right[:occupancy_position_to]
    else
      spec_b[:occupancy_position_to]
    end
    return false if from_a.nil? || from_b.nil?

    to_a = to_a || Float::INFINITY
    to_b = to_b || Float::INFINITY
    from_a <= to_b && from_b <= to_a
  end

  def detect_category_free_overlaps(profiles)
    decoded = profiles.map do |profile|
      case profile
      when Hash
        data = profile.with_indifferent_access
        decoded_key = decode_profile_key(data[:key]) if data[:key].present?
        family = (data[:family].presence || decoded_key&.fetch(:family)).to_sym
        category = data[:category].to_s.strip.presence
        from = data[:occupancy_position_from].presence || decoded_key&.dig(:occupancy_position_from)
        to = data.key?(:occupancy_position_to) ? data[:occupancy_position_to] : decoded_key&.dig(:occupancy_position_to)
        key = data[:key].presence || encode_profile_key(
          family, category: category, occupancy_position_from: from, occupancy_position_to: to
        )
        {
          key: key.to_s,
          family: family,
          category: category,
          occupancy_position_from: from,
          occupancy_position_to: to
        }
      else
        decoded_key = decode_profile_key(profile)
        {
          key: profile.to_s,
          family: decoded_key[:family],
          category: decoded_key[:category],
          occupancy_position_from: decoded_key[:occupancy_position_from],
          occupancy_position_to: decoded_key[:occupancy_position_to]
        }
      end
    end

    overlaps = []
    decoded.combination(2) do |left, right|
      next unless position_ranges_overlap?(left, right)
      next unless left[:category].blank? || right[:category].blank?
      next if left[:category].blank? && right[:category].blank?

      if left[:category].blank? && right[:category].present?
        overlaps << { category_free: left, categorized: right }
      elsif right[:category].blank? && left[:category].present?
        overlaps << { category_free: right, categorized: left }
      end
    end
    overlaps
  end

  def legacy_form?(components)
    charge_credit = components.reject { |c| c.economic_role == "expected_commission" }
    return false if charge_credit.empty?
    return false if matrix_form?(components)

    charge_credit.all? { |c| LEGACY_LABEL_TO_CELL.key?(c.label) }
  end

  def matrix_form?(components, categories_by_id: nil)
    charge_credit = components.reject { |c| c.economic_role == "expected_commission" }
    return false if charge_credit.empty?

    labels_roles = {}
    charge_credit.all? do |component|
      next false if LEGACY_ONLY_LABELS.include?(component.label)
      next false unless %w[supplier_charge supplier_credit].include?(component.economic_role)
      next false unless component.calculation_kind == "unit_rate"

      row_key = static_row_key_for_label(component.label)
      if row_key
        next false unless static_row_role(row_key) == component.economic_role
      else
        normalized = normalize_row_label(component.label)
        prior = labels_roles[normalized.downcase]
        if prior && prior != component.economic_role
          next false
        end
        labels_roles[normalized.downcase] = component.economic_role
      end

      profile_key_for_component(component, categories_by_id: categories_by_id).present?
    end
  end
end
