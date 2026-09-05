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
      intent.update!(status: "discarded", claimed_at: nil, last_error: "Subject version is no longer current")
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

      intent.update!(status: "processing", claimed_at: Time.current, attempt_count: intent.attempt_count + 1)
      intent
    end
  end

  def current_version?(intent)
    case intent.purpose
    when "team_invitation"
      intent.subject.invited? && intent.subject.invitation_version == intent.subject_version
    when "password_reset"
      intent.subject.password_reset_version == intent.subject_version
    end
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
