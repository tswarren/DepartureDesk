class DeliveryIntentJob < ApplicationJob
  queue_as :mailers

  retry_on StandardError, wait: :polynomially_longer, attempts: 5 do |job, error|
    DeliveryIntent.where(id: job.arguments.first, status: %w[pending processing]).update_all(
      status: "discarded",
      claimed_at: nil,
      last_error: "#{error.class}: #{error.message}".truncate(2_000),
      updated_at: Time.current
    )
  end

  def perform(intent_id)
    intent = claim(intent_id)
    return unless intent

    unless current_version?(intent)
      discard!(intent, "Subject version is no longer current")
      return
    end

    deliver(intent)
    intent.update!(status: "succeeded", delivered_at: Time.current, claimed_at: nil, last_error: nil)
  rescue StandardError => error
    if intent&.persisted? && intent.processing?
      intent.update_columns(
        status: "pending",
        claimed_at: nil,
        available_at: Time.current + retry_delay(intent.attempt_count),
        last_error: "#{error.class}: #{error.message}".truncate(2_000),
        updated_at: Time.current
      )
    end
    raise
  end

  private

  def claim(intent_id)
    DeliveryIntent.transaction do
      intent = DeliveryIntent.lock.find_by(id: intent_id)
      return unless intent&.pending? && intent.available_at <= Time.current

      unless current_version?(intent)
        discard!(intent, "Subject version is no longer current")
        return
      end

      intent.update!(status: "processing", claimed_at: Time.current, attempt_count: intent.attempt_count + 1)
      intent
    end
  end

  def discard!(intent, message)
    intent.update_columns(
      status: "discarded",
      claimed_at: nil,
      last_error: message,
      updated_at: Time.current
    )
  end

  def current_version?(intent)
    case intent.purpose
    when "team_invitation"
      team_invitation_current?(intent)
    when "password_reset"
      intent.subject&.password_reset_version == intent.subject_version
    end
  end

  def team_invitation_current?(intent)
    return false if intent.agency_id.blank?
    return false unless intent.agency&.active?

    subject = intent.subject
    return false unless subject.is_a?(AgencyMembership)
    return false unless intent.agency_id == subject.agency_id

    subject.invited? && subject.invitation_version == intent.subject_version
  end

  def deliver(intent)
    case intent.purpose
    when "team_invitation"
      InvitationsMailer.invite(intent.subject).deliver_now
    when "password_reset"
      PasswordsMailer.reset(intent.subject).deliver_now
    end
  end

  def retry_delay(attempt_count)
    [ attempt_count**4 + 2, 15.minutes.to_i ].min.seconds
  end
end
