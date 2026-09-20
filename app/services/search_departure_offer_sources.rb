# frozen_string_literal: true

class SearchDepartureOfferSources < AgencyCommand
  include OfferCommandSupport

  Candidate = Data.define(
    :arrangement, :version, :tentative, :item, :item_definition,
    :occurrence, :occurrence_definition, :resource, :resource_definition,
    :pool, :pool_definition, :effective_provider
  )
  Outcome = Data.define(:records, :truncated)
  LIMIT = 50
  FETCH_LIMIT = LIMIT + 1

  def self.call(**kwargs)
    new(**kwargs).call
  end

  def initialize(agency:, actor:, departure:, q: nil)
    @agency = agency
    @actor = actor
    @departure = departure
    @q = q.to_s
  end

  def call
    ensure_directory_actor!(@actor, @agency, :manage_departures)
    raise Error.new("Enter a search of 100 characters or fewer.", code: :invalid) if @q.length > 100

    departure = @agency.departures.find(@departure.id)
    candidates = []
    departure.supplier_arrangements
      .where(status: %w[draft active])
      .includes(:contracting_supplier, :governing_version, versions: [
        :arrangement_item_definitions, :service_occurrence_definitions,
        :supplier_resource_definitions, :capacity_pool_definitions
      ])
      .order(:name, :id)
      .each do |arrangement|
      selectable_versions_for(arrangement).each do |version, tentative|
        version.arrangement_item_definitions.order(:position, :id).each do |item_definition|
          item = item_definition.arrangement_item
          occurrences = version.service_occurrence_definitions.select { |row| row.arrangement_item_id == item.id }
          resources = version.supplier_resource_definitions.select { |row| row.arrangement_item_id == item.id }
          pools = version.capacity_pool_definitions.select { |row| row.arrangement_item_id == item.id }

          append_candidate(candidates, arrangement, version, tentative, item, item_definition, nil, nil, nil, nil, nil, nil)
          occurrences.sort_by { |row| [ row.starts_on, row.id ] }.each do |occurrence_definition|
            append_candidate(
              candidates, arrangement, version, tentative, item, item_definition,
              occurrence_definition.service_occurrence, occurrence_definition, nil, nil, nil, nil
            )
          end
          resources.sort_by(&:position).each do |resource_definition|
            append_candidate(
              candidates, arrangement, version, tentative, item, item_definition,
              nil, nil, resource_definition.supplier_resource, resource_definition, nil, nil
            )
            occurrences.each do |occurrence_definition|
              append_candidate(
                candidates, arrangement, version, tentative, item, item_definition,
                occurrence_definition.service_occurrence, occurrence_definition,
                resource_definition.supplier_resource, resource_definition, nil, nil
              )
              matching_pools = pools.select { |pool_definition|
                pool_definition.service_occurrence_id == occurrence_definition.service_occurrence_id &&
                  pool_definition.supplier_resource_id == resource_definition.supplier_resource_id
              }
              matching_pools.each do |pool_definition|
                append_candidate(
                  candidates, arrangement, version, tentative, item, item_definition,
                  occurrence_definition.service_occurrence, occurrence_definition,
                  resource_definition.supplier_resource, resource_definition,
                  pool_definition.capacity_pool, pool_definition
                )
              end
            end
          end
        end
      end
    end

    filtered = filter_query(candidates)
    Outcome.new(records: filtered.first(LIMIT), truncated: filtered.size > LIMIT)
  end

  private

  def selectable_versions_for(arrangement)
    draft = arrangement.versions.find { |version| version.draft? }
    governing = arrangement.governing_version
    versions = []
    if arrangement.active? && governing
      versions << [ governing, false ]
      versions << [ draft, true ] if draft && draft.id != governing.id
    elsif draft
      versions << [ draft, true ]
    end
    versions
  end

  def append_candidate(candidates, arrangement, version, tentative, item, item_definition,
    occurrence, occurrence_definition, resource, resource_definition, pool, pool_definition)
    provider = effective_provider_for(arrangement, item_definition, occurrence_definition)
    candidates << Candidate.new(
      arrangement:, version:, tentative:, item:, item_definition:,
      occurrence:, occurrence_definition:, resource:, resource_definition:,
      pool:, pool_definition:, effective_provider: provider
    )
  end

  def filter_query(candidates)
    needle = @q.strip.downcase
    return candidates if needle.blank?

    candidates.select do |candidate|
      haystack = [
        candidate.arrangement.name,
        candidate.item_definition.name,
        candidate.occurrence_definition&.name,
        candidate.resource_definition&.name,
        candidate.pool_definition&.label,
        candidate.effective_provider.display_name_for_directory
      ].compact.join(" ").downcase
      haystack.include?(needle)
    end
  end
end
