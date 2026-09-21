# frozen_string_literal: true

class CollectSelectedOfferBindings
  Result = Data.define(:status, :bindings, :reason)

  def initialize(version:, scenario:, package_preview: false)
    @version = version
    @scenario = scenario
    @package_preview = package_preview
  end

  def call
    bindings = @version.source_bindings.to_a
    selected_ids = @scenario.selected_binding_ids.map(&:to_s).uniq
    offer_ids = bindings.map { |binding| binding.id.to_s }
    return Result.new(status: :unknown_selection, bindings: [], reason: "A selected source is not part of this service offer.") if selected_ids.any? { |id| offer_ids.exclude?(id) }

    activations = selected_option_activations
    activated_binding_ids = activations.select { |row| row.activation_binding? }.map { |row| row.service_offer_source_binding_id.to_s }
    activated_group_keys = activations.select { |row| row.activation_alternative_group? }.map { |row| row.alternative_group_key }

    required = bindings.select(&:required?)
    gated = bindings.select(&:choice_gated?)
    grouped = bindings.select(&:alternative?).group_by(&:alternative_group_key)

    unreachable = gated.reject { |binding|
      activations.any? { |row| row.activation_binding? && row.service_offer_source_binding_id == binding.id }
    }
    if gated.any? && unreachable.any? && activations.any?
      # Selected options may not cover every gated binding; that is expected.
    end
    if gated.any? && option_activations_exist? && gated.any? { |binding| !gated_binding_reachable?(binding) }
      return Result.new(status: :unreachable_choice, bindings: [], reason: "Every choice-gated source must be reachable from an option.")
    end

    selected_gated = gated.select { |binding|
      activated_binding_ids.include?(binding.id.to_s) || selected_ids.include?(binding.id.to_s)
    }

    remaining_groups = grouped
    if @package_preview
      remaining_groups = grouped.reject { |key, _members|
        choice_gated_group?(key) && activated_group_keys.exclude?(key) && selected_ids.none? { |id|
          grouped[key]&.any? { |member| member.id.to_s == id }
        }
      }
    end

    chosen = remaining_groups.flat_map do |_key, members|
      picked = members.select { |binding| selected_ids.include?(binding.id.to_s) }
      return Result.new(status: :missing_alternative, bindings: [], reason: "Choose exactly one alternative source for this scenario.") if picked.empty?
      return Result.new(status: :ambiguous_alternative, bindings: [], reason: "An alternative group can select only one source.") if picked.size > 1

      picked
    end

    Result.new(status: :ok, bindings: (required + selected_gated + chosen).uniq, reason: nil)
  end

  private

  def selected_option_activations
    ids = @scenario.selected_option_ids.map(&:to_s)
    return [] if ids.empty?

    ServiceOfferChoiceOptionSourceActivation.where(
      service_offer_version_id: @version.id,
      service_offer_choice_option_id: ids
    ).to_a
  end

  def option_activations_exist?
    ServiceOfferChoiceOptionSourceActivation.where(service_offer_version_id: @version.id).exists?
  end

  def gated_binding_reachable?(binding)
    ServiceOfferChoiceOptionSourceActivation.where(
      service_offer_version_id: @version.id,
      service_offer_source_binding_id: binding.id,
      activation_kind: "binding"
    ).exists?
  end

  def choice_gated_group?(key)
    ServiceOfferChoiceOptionSourceActivation.where(
      service_offer_version_id: @version.id,
      activation_kind: "alternative_group",
      alternative_group_key: key
    ).exists?
  end
end
