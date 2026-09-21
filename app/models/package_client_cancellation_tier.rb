# frozen_string_literal: true

class PackageClientCancellationTier < ApplicationRecord
  include DraftVersionDefinition
  guards_draft_version :package_version

  THRESHOLD_KINDS = %w[on_or_before_date days_before_departure].freeze
  CONSEQUENCE_KINDS = %w[fixed percent manual_review].freeze

  belongs_to :agency
  belongs_to :departure
  belongs_to :package
  belongs_to :package_version
  belongs_to :package_client_cancellation_policy

  enum :threshold_kind, THRESHOLD_KINDS.index_by(&:itself), validate: true
  enum :consequence_kind, CONSEQUENCE_KINDS.index_by(&:itself), validate: true

  attr_readonly :agency_id, :departure_id, :package_id, :package_version_id,
    :package_client_cancellation_policy_id
end
