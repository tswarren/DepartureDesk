# frozen_string_literal: true

# Shared immutable candidate for Cruise deposit create/update and write-free preview.
class CruiseDepositCandidateNormalizer
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
    currency:
  )
    @template_key = template_key.to_s
    @form = form.to_h.with_indifferent_access
    @arrangement = arrangement
    @version = version
    @cruise_item = cruise_item
    @currency = currency
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

    Candidate.new(
      attributes: compiled.fetch(:attributes).freeze,
      coverage_links: Array(compiled.fetch(:attributes)[:coverage_links]).map(&:freeze).freeze,
      contributor_definition_ids: Array(compiled.fetch(:attributes)[:contributor_definition_ids]).freeze,
      template_key: @template_key,
      description: compiled.fetch(:attributes)[:description]
    )
  end
end
