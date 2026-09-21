# frozen_string_literal: true

class ValidatePackagePreviewSelections
  Result = Data.define(:ok, :message, :field, :selected_options)

  def initialize(package_version:, scenario:, selected_inclusion_ids: [])
    @package_version = package_version
    @scenario = scenario
    @selected_inclusion_ids = Array(selected_inclusion_ids).map(&:to_s)
  end

  def call
    selected_option_ids = @scenario.selected_option_ids.map(&:to_s).uniq
    collected_options = []
    allowed_option_ids = []

    selected_inclusions.each do |inclusion|
      version = inclusion.service_offer_version
      groups = version.choice_groups.includes(:service_offer_choice_options).order(:position).to_a
      next if groups.empty?

      version_option_ids = groups.flat_map { |group| group.service_offer_choice_options.map { |row| row.id.to_s } }
      allowed_option_ids.concat(version_option_ids)
      selected_for_version = selected_option_ids.select { |id| version_option_ids.include?(id) }

      groups.each do |group|
        options = group.service_offer_choice_options.sort_by(&:position)
        picked = options.select { |row| selected_for_version.include?(row.id.to_s) }
        if picked.size < group.min_selections || picked.size > group.max_selections
          return Result.new(
            ok: false,
            message: "Choose between #{group.min_selections} and #{group.max_selections} options for #{group.name}.",
            field: :choices,
            selected_options: []
          )
        end
        collected_options.concat(picked)
      end
    end

    foreign = selected_option_ids - allowed_option_ids.uniq
    if foreign.any?
      return Result.new(ok: false, message: "A selected choice is not part of this package.", field: :choices, selected_options: [])
    end

    Result.new(ok: true, message: nil, field: nil, selected_options: collected_options)
  end

  private

  def selected_inclusions
    inclusions = @package_version.inclusions.includes(
      service_offer_version: { choice_groups: :service_offer_choice_options }
    ).order(:position).to_a
    ids = @selected_inclusion_ids
    selected = inclusions.select { |inclusion| inclusion.included? || ids.include?(inclusion.id.to_s) }
    return inclusions.select(&:included?) if ids.empty?

    selected
  end
end
