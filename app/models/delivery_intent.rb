class DeliveryIntent < ApplicationRecord
  PURPOSES = %w[team_invitation password_reset].freeze
  STATUSES = %w[pending processing succeeded discarded].freeze

  belongs_to :agency, optional: true
  belongs_to :subject, polymorphic: true

  enum :status, STATUSES.index_by(&:itself), validate: true
  validates :purpose, inclusion: { in: PURPOSES }
  validates :idempotency_key, presence: true, uniqueness: true
  validates :subject_version, :attempt_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :purpose_matches_subject_and_agency

  scope :ready, -> { pending.where(available_at: ..Time.current) }
  scope :stale_processing, ->(before:) { processing.where(claimed_at: ...before) }
  scope :password_reset, -> { where(purpose: "password_reset") }

  def self.record!(subject:, purpose:, version:, agency: nil)
    intent = create!(
      agency: agency,
      subject: subject,
      purpose: purpose,
      subject_version: version,
      idempotency_key: "#{subject.class.model_name.singular}:#{subject.id}:#{version}:#{purpose}"
    )

    ActiveRecord.after_all_transactions_commit { intent.enqueue }
    intent
  end

  def enqueue
    job = DeliveryIntentJob.perform_later(id)
    job&.successfully_enqueued?
  rescue StandardError => error
    Rails.error.report(error, context: { delivery_intent_id: id })
    false
  end

  private

  def purpose_matches_subject_and_agency
    case purpose
    when "team_invitation"
      errors.add(:subject, "must be an agency membership") unless subject.is_a?(AgencyMembership)
      if subject.is_a?(AgencyMembership) && agency_id != subject.agency_id
        errors.add(:agency, "must own the invited membership")
      end
    when "password_reset"
      errors.add(:subject, "must be a user") unless subject.is_a?(User)
    end
  end
end
