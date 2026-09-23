# frozen_string_literal: true

# Shared immutable candidate for Cruise deposit create/update and write-free preview.
# Form compilation and M3E command-layer validation share one path so preview cannot
# approve graphs that save would reject.
class CruiseDepositCandidateNormalizer
  include DepositDefinitionCommandSupport

  Candidate = Data.define(
    :attributes,
    :coverage_links,
    :contributor_definition_ids,
    :template_key,
    :description
  )

  def self.call(**)
    new(**).call
  end

  def initialize(
    template_key:,
    form:,
    arrangement:,
    version:,
    cruise_item:,
    currency:,
    cumulative_definition: nil
  )
    @template_key = template_key.to_s
    @form = form.to_h.with_indifferent_access
    @arrangement = arrangement
    @version = version
    @cruise_item = cruise_item
    @currency = currency
    @cumulative_definition = cumulative_definition
  end

  def call
    compiled = CruiseDepositTemplateSupport.compile_attributes(
      template_key: @template_key,
      form: @form,
      arrangement: @arrangement,
      version: @version,
      cruise_item: @cruise_item,
      currency: @currency
    )

    command_attrs = compiled.fetch(:attributes).merge(
      _cumulative_definition: @cumulative_definition
    )
    normalized = normalize_deposit_attributes(@version, @arrangement, command_attrs)
    contributor_ids = Array(normalized[:contributor_links]).map { |row| row[:contributor_definition_id] }
    attributes = normalized.except(:contributor_links, :cost_links).merge(
      contributor_definition_ids: contributor_ids,
      cost_links: normalized[:cost_links]
    )

    Candidate.new(
      attributes: attributes.freeze,
      coverage_links: Array(normalized[:coverage_links]).map(&:freeze).freeze,
      contributor_definition_ids: contributor_ids.freeze,
      template_key: @template_key,
      description: normalized[:description]
    )
  end
end
