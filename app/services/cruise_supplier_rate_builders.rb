# frozen_string_literal: true

# Builder helpers for Cruise Supplier rate matrix (Slice 2A.2R).
# Requires CostCommandSupport and an @agency / @actor context.
module CruiseSupplierRateBuilders
  include CruiseSupplierRateSupport

  private

  def resolve_cruise_rate_context!(arrangement, version, resource_id)
    item_definition = version.arrangement_item_definitions.order(:position, :id).sole
    unless item_definition.category == "cruise"
      raise AgencyCommand::Error.new("That arrangement is not a Cruise sailing setup.", code: :invalid_state)
    end
    occurrence_definition = version.service_occurrence_definitions.order(:id).sole
    resource_definition = version.supplier_resource_definitions.lock.find_by!(supplier_resource_id: resource_id)
    item = lock_item_cost_context!(
      arrangement, version,
      item: item_definition.arrangement_item,
      occurrence: occurrence_definition.service_occurrence,
      resource: resource_definition.supplier_resource
    )
    [ item_definition, occurrence_definition, resource_definition, *item ]
  end

  def find_exact_context_source(version, item:, occurrence:, resource:)
    version.supplier_cost_sources.find_by(
      arrangement_item_id: item.id,
      service_occurrence_id: occurrence.id,
      supplier_resource_id: resource.id
    )
  end

  # Normalized matrix: { profiles:, custom_rows:, cells:, commission:, convert_legacy: }
  # profiles: [{ key:, family:, category: }]
  # cells: { "base_fare:first_second" => amount_minor_or_nil, ... }
  def normalize_matrix_payload(profiles:, cells:, commission:, currency:,
    custom_rows: nil, overlap_resolution: nil, convert_legacy: false)
    normalized_profiles = normalize_matrix_profiles(profiles)
    keys_before_overlap = normalized_profiles.map { |profile| profile.fetch(:key) }
    apply_overlap_resolution!(normalized_profiles, overlap_resolution)
    profile_keys = normalized_profiles.map { |profile| profile.fetch(:key) }
    accepted_profile_keys = (keys_before_overlap + profile_keys).uniq

    normalized_rows = normalize_custom_rows(custom_rows, cells)
    row_keys = STATIC_ROWS.keys.map(&:to_s) + normalized_rows.map { |row| row.fetch(:key) }

    input = cells.to_h.with_indifferent_access
    normalized_cells = {}
    input.each do |raw_key, raw_amount|
      row_key, profile_key = CruiseSupplierRateSupport.parse_cell_key(raw_key)
      row_key_s = row_key.to_s
      unless row_keys.include?(row_key_s)
        raise AgencyCommand::Error.new("Unknown rate matrix cell.", code: :invalid)
      end
      unless accepted_profile_keys.include?(profile_key.to_s)
        raise AgencyCommand::Error.new("Rate cell uses a profile that is not selected.", code: :invalid)
      end
      label = row_label_for_key(row_key_s, normalized_rows)
      amount = money_minor_or_nil(raw_amount, currency, label, major_units: true)
      next if amount.nil?

      normalized_cells[CruiseSupplierRateSupport.cell_key(row_key_s, profile_key)] = amount
    end

    remapped_cells = remap_cells_for_profiles(normalized_cells, normalized_profiles)
    profile_key_remap = build_profile_key_remap(keys_before_overlap, normalized_profiles)

    remapped_commission = commission
    if remapped_commission.present? && profile_key_remap.any?
      remapped_commission = remap_commission_profile_keys(remapped_commission, profile_key_remap)
    end

    {
      profiles: normalized_profiles,
      custom_rows: normalized_rows,
      cells: remapped_cells,
      commission: normalize_matrix_commission(
        remapped_commission, currency, profile_keys, remapped_cells, normalized_profiles
      ),
      convert_legacy: convert_legacy == true || convert_legacy.to_s == "true" || convert_legacy.to_s == "1"
    }
  end

  def build_profile_key_remap(keys_before, profiles_after)
    by_family = profiles_after.group_by { |profile| profile.fetch(:family) }
    remap = {}
    keys_before.each do |old_key|
      next if profiles_after.any? { |profile| profile.fetch(:key) == old_key }

      decoded = CruiseSupplierRateSupport.decode_profile_key(old_key)
      candidates = by_family[decoded[:family]] || []
      remap[old_key] = candidates.first.fetch(:key) if decoded[:category].blank? && candidates.size == 1
    end
    remap
  end

  def remap_commission_profile_keys(commission, remap)
    data = commission.to_h.deep_dup.with_indifferent_access
    %w[add_cells subtract_cells add_bases subtract_bases].each do |field|
      next unless data[field]

      data[field] = Array(data[field]).map { |cell| remap_cell_profile_key(cell, remap) }
    end
    if data[:amounts].is_a?(Hash)
      data[:amounts] = data[:amounts].transform_keys { |key| remap[key.to_s] || key.to_s }
    end
    if data[:rates].is_a?(Hash)
      data[:rates] = data[:rates].transform_keys { |key| remap[key.to_s] || key.to_s }
    end
    if data[:percentages].is_a?(Hash)
      data[:percentages] = data[:percentages].transform_keys { |key| remap[key.to_s] || key.to_s }
    end
    data
  end

  def remap_cell_profile_key(cell_key, remap)
    row_key, profile_key = CruiseSupplierRateSupport.parse_cell_key(cell_key)
    new_profile = remap[profile_key.to_s]
    return cell_key.to_s unless new_profile

    CruiseSupplierRateSupport.cell_key(row_key, new_profile)
  end

  def normalize_matrix_profiles(profiles)
    list = Array(profiles)
    list = default_smith_profiles if list.empty?

    normalized = list.map do |entry|
      if entry.is_a?(Hash)
        data = entry.with_indifferent_access
        decoded_key = CruiseSupplierRateSupport.decode_profile_key(data[:key]) if data[:key].present?
        family = (data[:family].presence || decoded_key&.fetch(:family)).to_sym
        category = data[:category].to_s.strip.presence
        from = data[:occupancy_position_from].presence || decoded_key&.dig(:occupancy_position_from)
        to = data.key?(:occupancy_position_to) ? data[:occupancy_position_to] : decoded_key&.dig(:occupancy_position_to)
      else
        decoded = CruiseSupplierRateSupport.decode_profile_key(entry)
        family = decoded[:family]
        category = decoded[:category]
        from = decoded[:occupancy_position_from]
        to = decoded[:occupancy_position_to]
      end

      unless PROFILE_FAMILIES.key?(family)
        raise AgencyCommand::Error.new("Unsupported rate profile.", code: :invalid)
      end
      family_spec = PROFILE_FAMILIES.fetch(family)
      if category.present?
        unless family_spec.fetch(:allows_participant_category)
          raise AgencyCommand::Error.new(
            "#{family_spec.fetch(:label)} cannot use a participant category.", code: :invalid
          )
        end
        if category.include?(PROFILE_CATEGORY_SEPARATOR)
          raise AgencyCommand::Error.new("Participant category labels cannot contain “__”.", code: :invalid)
        end
        category = normalize_text(category, "Participant category", SupplierCostParticipantCategory::LABEL_LIMIT)
      end

      if family_spec[:staff_supplied_positions]
        from_i = from.to_i
        raise AgencyCommand::Error.new("Enter a starting occupancy position.", code: :invalid) if from_i < 1

        to_i = if to.nil? || to.to_s.strip.empty?
          nil
        else
          value = to.to_i
          raise AgencyCommand::Error.new(
            "Ending occupancy position must be at or after the start.", code: :invalid
          ) if value < from_i

          value
        end
        key = CruiseSupplierRateSupport.encode_profile_key(
          family, category: category, occupancy_position_from: from_i, occupancy_position_to: to_i
        )
        {
          key: key.to_s,
          family: family,
          category: category,
          occupancy_position_from: from_i,
          occupancy_position_to: to_i
        }
      else
        key = (entry.is_a?(Hash) && entry.with_indifferent_access[:key].presence) ||
          CruiseSupplierRateSupport.encode_profile_key(family, category: category)
        {
          key: key.to_s,
          family: family,
          category: category,
          occupancy_position_from: family_spec[:occupancy_position_from],
          occupancy_position_to: family_spec[:occupancy_position_to]
        }
      end
    end

    keys = normalized.map { |profile| profile.fetch(:key) }
    if keys.uniq.size != keys.size
      raise AgencyCommand::Error.new("Rate profiles must be unique.", code: :invalid)
    end
    normalized
  end

  def normalize_custom_rows(custom_rows, cells)
    rows = Array(custom_rows).map do |entry|
      data = entry.to_h.with_indifferent_access
      label = normalize_text(data[:label], "Component description", SupplierCostComponent::LABEL_LIMIT)
      role = data[:economic_role].to_s
      unless CUSTOM_ROW_ROLES.include?(role)
        raise AgencyCommand::Error.new("Additional rows must be a Supplier charge or credit.", code: :invalid)
      end
      key = data[:key].to_s.strip.presence || CruiseSupplierRateSupport.slugify_custom_row_key(label)
      unless key.match?(CUSTOM_ROW_KEY_PATTERN)
        raise AgencyCommand::Error.new("Additional row keys must be lowercase letters, numbers, and underscores.", code: :invalid)
      end
      if STATIC_ROWS.key?(key.to_sym)
        raise AgencyCommand::Error.new("Additional row key conflicts with a static component.", code: :invalid)
      end
      { key: key, label: label, economic_role: role }
    end

    # Infer custom rows from cell keys when not declared (reconstruction helpers / partial params).
    cell_keys = cells.to_h.keys.map(&:to_s)
    cell_keys.each do |raw_key|
      row_key, = CruiseSupplierRateSupport.parse_cell_key(raw_key)
      next if row_key.nil? || STATIC_ROWS.key?(row_key)
      next if rows.any? { |row| row.fetch(:key) == row_key.to_s }

      raise AgencyCommand::Error.new(
        "Custom rate cell “#{raw_key}” needs a matching custom row definition.", code: :invalid
      )
    end

    labels = STATIC_ROWS.values.map { |spec| spec.fetch(:label).downcase } +
      rows.map { |row| row.fetch(:label).downcase }
    if labels.uniq.size != labels.size
      raise AgencyCommand::Error.new("Component labels must be unique.", code: :invalid)
    end
    rows
  end

  def apply_overlap_resolution!(profiles, overlap_resolution)
    overlaps = CruiseSupplierRateSupport.detect_category_free_overlaps(profiles)
    return if overlaps.empty?

    resolution = overlap_resolution.to_s.presence
    if resolution.blank?
      raise AgencyCommand::Error.new(
        "This schedule mixes category-free and category-specific traveler profiles that overlap. " \
        "Choose how the category-free profile applies before saving.",
        code: :invalid
      )
    end
    unless OVERLAP_RESOLUTIONS.include?(resolution)
      raise AgencyCommand::Error.new("Choose a valid overlap resolution.", code: :invalid)
    end

    case resolution
    when "edit_profiles"
      raise AgencyCommand::Error.new(
        "Edit or remove one of the overlapping rate profiles before saving.",
        code: :invalid
      )
    when "keep_every_traveler"
      # Explicit additive overlap; leave profiles unchanged.
      nil
    when "scope_existing_to_adult"
      overlaps.each do |overlap|
        free = overlap.fetch(:category_free)
        profile = profiles.find { |entry| entry.fetch(:key) == free.fetch(:key) }
        next unless profile && profile[:category].blank?

        profile[:category] = ADULT_CATEGORY_LABEL
        profile[:key] = CruiseSupplierRateSupport.encode_profile_key(
          profile.fetch(:family),
          category: ADULT_CATEGORY_LABEL,
          occupancy_position_from: profile[:occupancy_position_from],
          occupancy_position_to: profile[:occupancy_position_to]
        )
      end
      keys = profiles.map { |profile| profile.fetch(:key) }
      if keys.uniq.size != keys.size
        raise AgencyCommand::Error.new(
          "Scoping overlapping profiles to Adult created duplicate columns. Edit the profiles.",
          code: :invalid
        )
      end
    end
  end

  def remap_cells_for_profiles(cells, profiles)
    # After scope_existing_to_adult, keys may have changed; accept either old or new profile keys
    # for category-free → Adult remaps by family when a single Adult (or sole) profile remains.
    by_family = profiles.group_by { |profile| profile.fetch(:family) }
    remapped = {}
    cells.each do |cell_key, amount|
      row_key, profile_key = CruiseSupplierRateSupport.parse_cell_key(cell_key)
      if profiles.any? { |profile| profile.fetch(:key) == profile_key.to_s }
        remapped[CruiseSupplierRateSupport.cell_key(row_key, profile_key)] = amount
        next
      end

      decoded = CruiseSupplierRateSupport.decode_profile_key(profile_key)
      candidates = by_family[decoded[:family]] || []
      target = if decoded[:category].blank?
        candidates.find { |profile| profile[:category] == ADULT_CATEGORY_LABEL } ||
          (candidates.size == 1 ? candidates.first : nil)
      else
        candidates.find { |profile| profile[:category].to_s == decoded[:category].to_s }
      end
      if target
        remapped[CruiseSupplierRateSupport.cell_key(row_key, target.fetch(:key))] = amount
      else
        raise AgencyCommand::Error.new("Rate cell uses a profile that is not selected.", code: :invalid)
      end
    end
    remapped
  end

  def row_label_for_key(row_key, custom_rows)
    if STATIC_ROWS.key?(row_key.to_sym)
      CruiseSupplierRateSupport.static_row_label(row_key)
    else
      custom_rows.find { |row| row.fetch(:key) == row_key.to_s }&.fetch(:label) || row_key.to_s
    end
  end

  def row_role_for_key(row_key, custom_rows)
    if STATIC_ROWS.key?(row_key.to_sym)
      CruiseSupplierRateSupport.static_row_role(row_key)
    else
      custom_rows.find { |row| row.fetch(:key) == row_key.to_s }&.fetch(:economic_role)
    end
  end

  def default_smith_profiles
    %i[first_second additional every_traveler every_cabin single_supplement].map do |family|
      { key: family.to_s, family: family, category: nil }
    end
  end

  def normalize_matrix_commission(commission, currency, profile_keys, cells, profiles)
    input = (commission || {}).to_h.with_indifferent_access
    method = (input[:method].presence || "not_provided").to_s
    unless COMMISSION_METHODS.include?(method)
      raise AgencyCommand::Error.new("Choose how expected commission is stated.", code: :invalid)
    end

    case method
    when "not_provided"
      { method: method }
    when "dollar"
      amounts = {}
      raw_amounts = (input[:amounts] || {}).to_h.with_indifferent_access
      if raw_amounts.empty? && (input.key?(:amount) || input.key?(:amount_minor_units))
        basis = input[:applies_per].presence || input[:quantity_basis].presence
        basis = "persons" if basis.to_s == "traveler"
        basis = "resource_units" if basis.to_s == "cabin"
        profile_key = basis.to_s == "resource_units" ? "every_cabin" : "every_traveler"
        amount = money_minor_or_nil(
          input.key?(:amount) ? input[:amount] : input[:amount_minor_units],
          currency, "Commission amount", major_units: input.key?(:amount)
        )
        raise AgencyCommand::Error.new("Enter the commission amount.", code: :invalid) if amount.nil?
        amounts[profile_key] = amount
        unless profile_keys.include?(profile_key)
          profiles << { key: profile_key, family: profile_key.to_sym, category: nil }
          profile_keys = (profile_keys + [ profile_key ]).uniq
        end
      else
        raw_amounts.each do |profile_key, raw|
          key = profile_key.to_s
          decoded = CruiseSupplierRateSupport.decode_profile_key(key)
          unless PROFILE_FAMILIES.key?(decoded[:family])
            raise AgencyCommand::Error.new("Dollar commission uses an unsupported profile.", code: :invalid)
          end
          amount = money_minor_or_nil(raw, currency, "Commission amount", major_units: true)
          next if amount.nil?

          amounts[key] = amount
        end
        raise AgencyCommand::Error.new("Enter at least one dollar commission amount.", code: :invalid) if amounts.empty?
      end
      { method: method, amounts: amounts }
    when "percentage"
      shared = !(input[:shared] == false || input[:shared].to_s == "0" || input[:shared].to_s.casecmp?("false"))
      add_keys = Array(input[:add_bases] || input[:add_cells]).map(&:to_s)
      subtract_keys = Array(input[:subtract_bases] || input[:subtract_cells]).map(&:to_s)
      add_keys = expand_legacy_commission_bases(add_keys, cells, :charge)
      subtract_keys = expand_legacy_commission_bases(subtract_keys, cells, :credit)

      if shared
        unknown = (add_keys + subtract_keys).reject { |key| cells.key?(key) }
        if unknown.any?
          raise AgencyCommand::Error.new("Commission bases must match populated rate cells.", code: :invalid)
        end
        if add_keys.empty? && subtract_keys.empty?
          raise AgencyCommand::Error.new("Select at least one commission base.", code: :invalid)
        end
        rate = percentage_rate_from_input(input)
        {
          method: method,
          rate: rate,
          shared: true,
          add_cells: add_keys,
          subtract_cells: subtract_keys
        }
      else
        rates = {}
        if input[:profile_rates].present?
          Array(input[:profile_rates]).each do |(profile_key, spec)|
            data = spec.to_h.with_indifferent_access
            key = profile_key.to_s
            percent = if data.key?(:percentage)
              decimal_or_nil(data[:percentage], "Commission percentage")
            elsif data.key?(:rate)
              raw_rate = decimal_or_nil(data[:rate], "Commission rate")
              raise AgencyCommand::Error.new("Enter the commission percentage.", code: :invalid) if raw_rate.nil?
              raw_rate * 100
            end
            raise AgencyCommand::Error.new(
              "Enter a commission percentage for each rate profile.", code: :invalid
            ) if percent.nil?
            rates[key] = percent / 100
            add_keys.concat(Array(data[:add_cells] || data[:add_bases]).map(&:to_s))
            subtract_keys.concat(Array(data[:subtract_cells] || data[:subtract_bases]).map(&:to_s))
          end
          add_keys = expand_legacy_commission_bases(add_keys.uniq, cells, :charge)
          subtract_keys = expand_legacy_commission_bases(subtract_keys.uniq, cells, :credit)
        else
          raw_rates = (input[:rates] || input[:percentages] || {}).to_h.with_indifferent_access
          profile_keys_with_bases = (add_keys + subtract_keys).map { |key|
            _row, profile_key = CruiseSupplierRateSupport.parse_cell_key(key)
            profile_key.to_s
          }.uniq
          profile_keys_with_bases.each do |profile_key|
            raw = raw_rates[profile_key]
            raw = input[:percentage] if raw.nil? && profile_keys_with_bases.size == 1
            if raw.nil? && input.key?(:rate) && profile_keys_with_bases.size == 1
              rates[profile_key] = decimal_or_nil(input[:rate], "Commission rate").tap do |value|
                raise AgencyCommand::Error.new("Enter the commission percentage.", code: :invalid) if value.nil?
              end
              next
            end
            percent = decimal_or_nil(raw, "Commission percentage")
            raise AgencyCommand::Error.new(
              "Enter a commission percentage for each rate profile.", code: :invalid
            ) if percent.nil?
            rates[profile_key] = percent / 100
          end
        end
        unknown = (add_keys + subtract_keys).reject { |key| cells.key?(key) }
        if unknown.any?
          raise AgencyCommand::Error.new("Commission bases must match populated rate cells.", code: :invalid)
        end
        if add_keys.empty? && subtract_keys.empty?
          raise AgencyCommand::Error.new("Select at least one commission base.", code: :invalid)
        end
        {
          method: method,
          shared: false,
          rates: rates,
          add_cells: add_keys.uniq,
          subtract_cells: subtract_keys.uniq
        }
      end
    end
  end

  def percentage_rate_from_input(input)
    if input.key?(:percentage)
      percent = decimal_or_nil(input[:percentage], "Commission percentage")
      raise AgencyCommand::Error.new("Enter the commission percentage.", code: :invalid) if percent.nil?
      percent / 100
    else
      decimal_or_nil(input[:rate], "Commission rate").tap do |value|
        raise AgencyCommand::Error.new("Enter the commission percentage.", code: :invalid) if value.nil?
      end
    end
  end

  def expand_legacy_commission_bases(keys, cells, role)
    keys.flat_map do |key|
      next [ key ] if cells.key?(key)

      mapped = legacy_term_key_to_cell_keys(key.to_sym, role)
      mapped.select { |cell| cells.key?(cell) }
    end.uniq
  end

  def legacy_term_key_to_cell_keys(term_key, _role)
    mapping = {
      first_second_fare: [ "base_fare:first_second" ],
      additional_fare: [ "base_fare:additional" ],
      single_supplement: [ "base_fare:single_supplement" ],
      nccf: [ "nccf:every_traveler" ],
      taxes_fees: [ "taxes_fees:every_traveler" ],
      first_second_discount: [ "discount:first_second" ],
      additional_discount: [ "discount:additional" ]
    }
    mapping.fetch(term_key, [])
  end

  def resolve_matrix_participant_categories!(matrix, version:, item:)
    matrix.fetch(:profiles).each do |profile|
      category_label = profile[:category]
      if category_label.present?
        profile[:category_id] = ensure_participant_category!(version, item: item, label: category_label).id
      else
        profile[:category_id] = nil
      end
    end
    matrix
  end

  def component_attributes_for_cell(row_key, profile, amount_minor_units, custom_rows:)
    row_key_s = row_key.to_s
    family = PROFILE_FAMILIES.fetch(profile.fetch(:family))
    label = row_label_for_key(row_key_s, custom_rows)
    role = row_role_for_key(row_key_s, custom_rows)
    {
      label: label,
      economic_role: role,
      calculation_kind: "unit_rate",
      amount_minor_units: amount_minor_units,
      quantity_basis: family.fetch(:quantity_basis),
      occupancy_position_from: profile[:occupancy_position_from] || family[:occupancy_position_from],
      occupancy_position_to: profile.key?(:occupancy_position_to) ? profile[:occupancy_position_to] : family[:occupancy_position_to],
      percentage_treatment: nil,
      participant_category_id: profile[:category_id],
      pass_through: false,
      rate: nil,
      minimum_minor_units: nil,
      minimum_quantity: nil
    }
  end

  def find_component_for_cell(components, row_key, profile, custom_rows:)
    label = row_label_for_key(row_key, custom_rows)
    role = row_role_for_key(row_key, custom_rows)
    family = PROFILE_FAMILIES.fetch(profile.fetch(:family))
    from = profile[:occupancy_position_from] || family[:occupancy_position_from]
    to = profile.key?(:occupancy_position_to) ? profile[:occupancy_position_to] : family[:occupancy_position_to]
    exact = components.find do |component|
      component.label == label &&
        component.economic_role == role &&
        component.quantity_basis == family.fetch(:quantity_basis) &&
        component.occupancy_position_from == from &&
        component.occupancy_position_to == to &&
        component.participant_category_id == profile[:category_id] &&
        component.economic_role != "expected_commission"
    end
    return exact if exact

    # Reuse category-free sibling when scoping a column to Adult (overlap resolution).
    if profile[:category] == ADULT_CATEGORY_LABEL
      components.find do |component|
        component.label == label &&
          component.economic_role == role &&
          component.quantity_basis == family.fetch(:quantity_basis) &&
          component.occupancy_position_from == from &&
          component.occupancy_position_to == to &&
          component.participant_category_id.nil? &&
          component.economic_role != "expected_commission"
      end
    end
  end

  def find_legacy_component_for_cell(components, row_key, profile)
    return nil if profile[:category].present?

    LEGACY_LABEL_TO_CELL.each do |legacy_label, pair|
      next unless pair == [ row_key.to_sym, profile.fetch(:family) ]

      return components.find { |c| c.label == legacy_label }
    end
    nil
  end

  def sync_matrix_components!(definition, matrix:, converting_legacy: false)
    components = definition.supplier_cost_components.lock.to_a
    profiles_by_key = matrix.fetch(:profiles).index_by { |profile| profile.fetch(:key) }
    custom_rows = matrix.fetch(:custom_rows)

    assignments = []
    claimed_ids = []
    matrix.fetch(:cells).each do |cell_key, amount|
      row_key, profile_key = CruiseSupplierRateSupport.parse_cell_key(cell_key)
      profile = profiles_by_key.fetch(profile_key.to_s)
      attrs = component_attributes_for_cell(row_key, profile, amount, custom_rows: custom_rows)
      existing = find_component_for_cell(components, row_key, profile, custom_rows: custom_rows)
      if existing.nil? && converting_legacy
        existing = find_legacy_component_for_cell(components, row_key, profile)
      end
      if existing && claimed_ids.include?(existing.id)
        existing = nil
      end
      claimed_ids << existing.id if existing
      assignments << { cell_key: cell_key, attrs: attrs, existing: existing }
    end

    kept_ids = claimed_ids
    # Drop commission first so position reshuffles cannot create forward bases.
    components.select { |c| c.economic_role == "expected_commission" }.each do |component|
      destroy_component_and_dependent_bases!(definition, component)
    end
    components.each do |component|
      next if component.economic_role == "expected_commission"
      next if kept_ids.include?(component.id)

      destroy_component_and_dependent_bases!(definition, component)
    end

    cell_to_component = {}
    # Park kept rows at high positions first to avoid unique (definition, position) swaps.
    park = 1_000
    assignments.each_with_index do |assignment, index|
      existing = assignment[:existing]
      next unless existing

      existing.update_columns(position: park + index)
    end

    position = 1
    assignments.each do |assignment|
      attrs = assignment.fetch(:attrs)
      existing = assignment[:existing]
      component = if existing
        existing.update!(attrs.merge(position: position))
        existing
      else
        build_supplier_cost_component_already_locked!(
          definition: definition, attributes: attrs, position: position, base_links: []
        )
      end
      cell_to_component[assignment.fetch(:cell_key)] = component
      position += 1
    end

    sync_matrix_commission!(
      definition, matrix.fetch(:commission), cell_to_component, position, matrix.fetch(:profiles)
    )
    renumber_components!(definition)
    touch_definition_after_change!(definition)
  end

  def sync_matrix_commission!(definition, commission, cell_to_component, start_position, profiles)
    components = definition.supplier_cost_components.reload.lock.to_a
    commission_components = components.select { |c| c.economic_role == "expected_commission" }

    if commission.fetch(:method) == "not_provided"
      commission_components.each { |c| destroy_component_and_dependent_bases!(definition, c) }
      return
    end

    if commission.fetch(:method) == "percentage"
      if commission.fetch(:shared, true)
        sync_shared_percentage_commission!(
          definition, commission, cell_to_component, start_position, commission_components
        )
      else
        sync_profile_percentage_commissions!(
          definition, commission, cell_to_component, start_position, commission_components
        )
      end
      return
    end

    sync_dollar_commission!(definition, commission, start_position, commission_components, profiles)
  end

  def sync_shared_percentage_commission!(definition, commission, cell_to_component, start_position, commission_components)
    attrs = {
      label: COMMISSION_LABEL,
      economic_role: "expected_commission",
      calculation_kind: "percentage",
      rate: commission.fetch(:rate),
      percentage_treatment: "additive",
      pass_through: false,
      amount_minor_units: nil,
      quantity_basis: nil,
      occupancy_position_from: nil,
      occupancy_position_to: nil,
      participant_category_id: nil,
      minimum_minor_units: nil,
      minimum_quantity: nil
    }
    primary = commission_components.find { |c| c.calculation_kind == "percentage" } || commission_components.first
    (commission_components - [ primary ].compact).each do |extra|
      destroy_component_and_dependent_bases!(definition, extra)
    end
    commission_component = if primary&.calculation_kind == "percentage"
      primary.update!(attrs.merge(position: start_position))
      primary
    else
      primary&.then { |c| destroy_component_and_dependent_bases!(definition, c) }
      build_supplier_cost_component_already_locked!(
        definition: definition, attributes: attrs, position: start_position, base_links: []
      )
    end
    replace_base_links!(definition, commission_component, commission_base_links(commission, cell_to_component))
  end

  def sync_profile_percentage_commissions!(definition, commission, cell_to_component, start_position, commission_components)
    # Recreate so each profile rounds independently; destroy existing percentage/dollar commissions first.
    commission_components.each { |c| destroy_component_and_dependent_bases!(definition, c) }

    rates = commission.fetch(:rates)
    add_by_profile = commission.fetch(:add_cells).group_by { |key|
      _row, profile_key = CruiseSupplierRateSupport.parse_cell_key(key)
      profile_key.to_s
    }
    subtract_by_profile = commission.fetch(:subtract_cells).group_by { |key|
      _row, profile_key = CruiseSupplierRateSupport.parse_cell_key(key)
      profile_key.to_s
    }
    position = start_position
    rates.each do |profile_key, rate|
      profile_commission = {
        add_cells: add_by_profile[profile_key.to_s] || [],
        subtract_cells: subtract_by_profile[profile_key.to_s] || []
      }
      next if profile_commission[:add_cells].empty? && profile_commission[:subtract_cells].empty?

      attrs = {
        label: COMMISSION_LABEL,
        economic_role: "expected_commission",
        calculation_kind: "percentage",
        rate: rate,
        percentage_treatment: "additive",
        pass_through: false,
        amount_minor_units: nil,
        quantity_basis: nil,
        occupancy_position_from: nil,
        occupancy_position_to: nil,
        participant_category_id: nil,
        minimum_minor_units: nil,
        minimum_quantity: nil
      }
      component = build_supplier_cost_component_already_locked!(
        definition: definition, attributes: attrs, position: position, base_links: []
      )
      replace_base_links!(definition, component, commission_base_links(profile_commission, cell_to_component))
      position += 1
    end
  end

  def commission_base_links(commission, cell_to_component)
    links = []
    commission.fetch(:add_cells).each do |cell_key|
      component = cell_to_component[cell_key]
      raise AgencyCommand::Error.new(
        "Select commission bases that are present on the rate schedule.", code: :invalid
      ) unless component

      links << { base_component_id: component.id, direction: "add", position: links.size + 1 }
    end
    commission.fetch(:subtract_cells).each do |cell_key|
      component = cell_to_component[cell_key]
      raise AgencyCommand::Error.new(
        "Select commission bases that are present on the rate schedule.", code: :invalid
      ) unless component

      links << { base_component_id: component.id, direction: "subtract", position: links.size + 1 }
    end
    links
  end

  def sync_dollar_commission!(definition, commission, start_position, commission_components, profiles)
    amounts = commission.fetch(:amounts)
    profiles_by_key = profiles.index_by { |profile| profile.fetch(:key) }
    keep_profiles = amounts.keys.map { |key| profiles_by_key[key.to_s] || {
      key: key.to_s,
      family: CruiseSupplierRateSupport.decode_profile_key(key)[:family],
      category: CruiseSupplierRateSupport.decode_profile_key(key)[:category],
      category_id: nil
    } }

    commission_components.each do |component|
      next unless component.calculation_kind == "unit_rate"

      matching = keep_profiles.any? do |profile|
        family = PROFILE_FAMILIES.fetch(profile.fetch(:family))
        from = profile[:occupancy_position_from] || family[:occupancy_position_from]
        to = profile.key?(:occupancy_position_to) ? profile[:occupancy_position_to] : family[:occupancy_position_to]
        component.quantity_basis == family.fetch(:quantity_basis) &&
          component.occupancy_position_from == from &&
          component.occupancy_position_to == to &&
          component.participant_category_id == profile[:category_id]
      end
      destroy_component_and_dependent_bases!(definition, component) unless matching
    end
    # Also remove percentage commissions when switching to dollar.
    definition.supplier_cost_components.reload.lock.select { |c|
      c.economic_role == "expected_commission" && c.calculation_kind == "percentage"
    }.each { |c| destroy_component_and_dependent_bases!(definition, c) }

    commission_components = definition.supplier_cost_components.reload.lock.select { |c|
      c.economic_role == "expected_commission"
    }

    used_ids = []
    position = start_position
    amounts.each do |profile_key, amount|
      decoded = CruiseSupplierRateSupport.decode_profile_key(profile_key)
      profile = profiles_by_key[profile_key.to_s] || {
        key: profile_key.to_s,
        family: decoded[:family],
        category: decoded[:category],
        occupancy_position_from: decoded[:occupancy_position_from],
        occupancy_position_to: decoded[:occupancy_position_to],
        category_id: nil
      }
      family = PROFILE_FAMILIES.fetch(profile.fetch(:family))
      from = profile[:occupancy_position_from] || family[:occupancy_position_from]
      to = profile.key?(:occupancy_position_to) ? profile[:occupancy_position_to] : family[:occupancy_position_to]
      attrs = {
        label: COMMISSION_LABEL,
        economic_role: "expected_commission",
        calculation_kind: "unit_rate",
        amount_minor_units: amount,
        quantity_basis: family.fetch(:quantity_basis),
        occupancy_position_from: from,
        occupancy_position_to: to,
        participant_category_id: profile[:category_id],
        pass_through: false,
        rate: nil,
        percentage_treatment: nil,
        minimum_minor_units: nil,
        minimum_quantity: nil
      }
      existing = commission_components.find do |c|
        c.calculation_kind == "unit_rate" &&
          c.quantity_basis == family.fetch(:quantity_basis) &&
          c.occupancy_position_from == from &&
          c.occupancy_position_to == to &&
          c.participant_category_id == profile[:category_id] &&
          !used_ids.include?(c.id)
      end
      component = if existing
        existing.update!(attrs.merge(position: position))
        replace_base_links!(definition, existing, [])
        existing
      else
        build_supplier_cost_component_already_locked!(
          definition: definition, attributes: attrs, position: position, base_links: []
        )
      end
      used_ids << component.id
      position += 1
    end
    commission_components.each do |component|
      next if used_ids.include?(component.id)

      destroy_component_and_dependent_bases!(definition, component)
    end
  end

  def destroy_component_and_dependent_bases!(definition, component)
    return if component.nil?

    definition.supplier_cost_components.includes(:supplier_cost_component_bases).find_each do |other|
      other.supplier_cost_component_bases.where(base_component_id: component.id).lock.each(&:destroy!)
    end
    component.supplier_cost_component_bases.order(:id).lock.each(&:destroy!)
    component.destroy!
  end

  def renumber_components!(definition)
    definition.supplier_cost_components.order(:position, :id).lock.each_with_index do |component, index|
      component.update!(position: index + 1) if component.position != index + 1
    end
  end

  def clear_readiness_for_context!(version, item:, occurrence:, resource:)
    sources = version.supplier_cost_sources.where(
      arrangement_item_id: item.id,
      service_occurrence_id: occurrence.id,
      supplier_resource_id: resource.id
    )
    sources.find_each do |source|
      source.supplier_cost_definitions.lock.each { |definition| clear_readiness!(definition) }
    end
  end

  def ensure_traveler_category!(version, item:)
    ensure_participant_category!(version, item: item, label: PARTICIPANT_CATEGORY_LABEL)
  end

  def ensure_participant_category!(version, item:, label:)
    normalized = normalize_text(label, "Participant category", SupplierCostParticipantCategory::LABEL_LIMIT)
    version.supplier_cost_participant_categories.find_or_initialize_by(
      arrangement_item_id: item.id, label: normalized
    ).tap do |category|
      if category.new_record?
        siblings = version.supplier_cost_participant_categories.where(arrangement_item: item).order(:position, :id).lock.to_a
        category.assign_attributes(
          owner_attributes_for(version).merge(position: siblings.map(&:position).max.to_i + 1)
        )
        category.save!
      end
    end
  end

  # Smith matrix helper used by tests and default create payloads.
  # Returns major-unit strings keyed by matrix cell; normalize_matrix_payload converts once.
  def smith_matrix_cells_from_legacy_terms(terms, _currency = nil)
    input = terms.to_h.with_indifferent_access
    mapping = {
      first_second_fare: "base_fare:first_second",
      additional_fare: "base_fare:additional",
      single_supplement: "base_fare:single_supplement",
      nccf: "nccf:every_traveler",
      first_second_discount: "discount:first_second",
      additional_discount: "discount:additional",
      taxes_fees: "taxes_fees:every_traveler"
    }
    cells = {}
    mapping.each do |term_key, cell_key|
      next unless input.key?(term_key) || input.key?(term_key.to_s)

      cells[cell_key] = input[term_key]
    end
    cells
  end
end
