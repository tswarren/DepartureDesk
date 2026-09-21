# frozen_string_literal: true

class ServiceOfferChoiceOptionSourceActivation < ApplicationRecord
  include DraftVersionDefinition
  guards_draft_version :service_offer_version

  KINDS = %w[binding alternative_group none].freeze

  belongs_to :agency
  belongs_to :departure
  belongs_to :service_offer
  belongs_to :service_offer_version
  belongs_to :service_offer_choice_option
  belongs_to :service_offer_source_binding, optional: true

  enum :activation_kind, KINDS.index_by(&:itself), validate: true, prefix: :activation

  attr_readonly :agency_id, :departure_id, :service_offer_id, :service_offer_version_id,
    :service_offer_choice_option_id

  normalizes :alternative_group_key, with: ->(value) { value.to_s.strip.presence }
end
