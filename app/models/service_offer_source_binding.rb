# frozen_string_literal: true

class ServiceOfferSourceBinding < ApplicationRecord
  include DraftVersionDefinition
  guards_draft_version :service_offer_version

  MEMBERSHIP_KINDS = %w[required alternative].freeze
  TITLE_PROVENANCES = %w[source_name staff_entered].freeze
  DESCRIPTION_PROVENANCES = %w[source_description staff_entered none].freeze
  GROUP_KEY_LIMIT = 80
  GROUP_LABEL_LIMIT = 160

  belongs_to :agency
  belongs_to :departure
  belongs_to :service_offer
  belongs_to :service_offer_version
  belongs_to :supplier_arrangement
  belongs_to :arrangement_item
  belongs_to :service_occurrence, optional: true
  belongs_to :supplier_resource, optional: true
  belongs_to :capacity_pool, optional: true
  belongs_to :supplier_arrangement_version
  belongs_to :arrangement_item_definition
  belongs_to :service_occurrence_definition, optional: true
  belongs_to :supplier_resource_definition, optional: true
  belongs_to :capacity_pool_definition, optional: true

  enum :membership_kind, MEMBERSHIP_KINDS.index_by(&:itself), validate: true, default: "required"
  enum :client_title_provenance, TITLE_PROVENANCES.index_by(&:itself),
    validate: true, default: "source_name", prefix: :title
  enum :client_description_provenance, DESCRIPTION_PROVENANCES.index_by(&:itself),
    validate: true, default: "none", prefix: :description

  attr_readonly :agency_id, :departure_id, :service_offer_id, :service_offer_version_id

  normalizes :alternative_group_key, :alternative_group_label,
    with: ->(value) { value.to_s.strip.presence }

  validates :position, numericality: { only_integer: true, greater_than: 0 }
  validates :alternative_group_key, length: { maximum: GROUP_KEY_LIMIT }, allow_nil: true
  validates :alternative_group_label, length: { maximum: GROUP_LABEL_LIMIT }, allow_nil: true
  validate :alternative_group_matches_membership
  validate :pool_requires_occurrence_and_resource
  validate :child_definitions_are_paired

  def item_only?
    service_occurrence_id.blank? && supplier_resource_id.blank? && capacity_pool_id.blank?
  end

  private

  def alternative_group_matches_membership
    if alternative?
      errors.add(:alternative_group_key, "can't be blank") if alternative_group_key.blank?
      errors.add(:alternative_group_label, "can't be blank") if alternative_group_label.blank?
    else
      errors.add(:alternative_group_key, "must be blank for a required binding") if alternative_group_key.present?
      errors.add(:alternative_group_label, "must be blank for a required binding") if alternative_group_label.present?
    end
  end

  def pool_requires_occurrence_and_resource
    return if capacity_pool_id.blank?
    return if service_occurrence_id.present? && supplier_resource_id.present?

    errors.add(:base, "A Pool pin requires both an Occurrence and a Resource")
  end

  def child_definitions_are_paired
    if service_occurrence_id.present? ^ service_occurrence_definition_id.present?
      errors.add(:base, "Occurrence and occurrence definition must be paired")
    end
    if supplier_resource_id.present? ^ supplier_resource_definition_id.present?
      errors.add(:base, "Resource and resource definition must be paired")
    end
    if capacity_pool_id.present? ^ capacity_pool_definition_id.present?
      errors.add(:base, "Pool and pool definition must be paired")
    end
  end
end
