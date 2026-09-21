# frozen_string_literal: true

class ServiceOfferClientPaymentScheduleLine < ApplicationRecord
  include DraftVersionDefinition
  guards_draft_version :service_offer_version

  DUE_KINDS = %w[fixed_on named_relative_milestone].freeze
  AMOUNT_KINDS = %w[fixed percent].freeze

  belongs_to :agency
  belongs_to :departure
  belongs_to :service_offer
  belongs_to :service_offer_version
  belongs_to :service_offer_client_payment_schedule

  enum :due_kind, DUE_KINDS.index_by(&:itself), validate: true
  enum :amount_kind, AMOUNT_KINDS.index_by(&:itself), validate: true, prefix: :amount

  attr_readonly :agency_id, :departure_id, :service_offer_id, :service_offer_version_id,
    :service_offer_client_payment_schedule_id
end
