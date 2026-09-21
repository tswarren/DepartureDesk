# frozen_string_literal: true

class PackageClientPaymentScheduleLine < ApplicationRecord
  include DraftVersionDefinition
  guards_draft_version :package_version

  DUE_KINDS = %w[fixed_on named_relative_milestone].freeze
  AMOUNT_KINDS = %w[fixed percent].freeze

  belongs_to :agency
  belongs_to :departure
  belongs_to :package
  belongs_to :package_version
  belongs_to :package_client_payment_schedule

  enum :due_kind, DUE_KINDS.index_by(&:itself), validate: true
  enum :amount_kind, AMOUNT_KINDS.index_by(&:itself), validate: true, prefix: :amount

  attr_readonly :agency_id, :departure_id, :package_id, :package_version_id,
    :package_client_payment_schedule_id
end
