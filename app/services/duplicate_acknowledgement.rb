class DuplicateAcknowledgement
  PURPOSE = "directory.duplicate_acknowledgement"
  TTL = 15.minutes
  REASONS = %w[confirmed_distinct shared_contact insufficient_match other_reviewed].freeze

  def self.issue(payload)
    verifier.generate(payload.merge(
      "nonce" => SecureRandom.hex(16),
      "issued_at" => Time.current.iso8601,
      "expires_at" => TTL.from_now.iso8601
    ), purpose: PURPOSE)
  end

  def self.verify!(token, agency:, actor:, command:)
    payload = verifier.verified(token.to_s, purpose: PURPOSE)
    raise AgencyCommand::Error.new("That acknowledgement is not valid.", code: :invalid) if payload.blank?
    unless payload["agency_id"] == agency.id && payload["actor_id"] == actor.id && payload["command"] == command
      raise AgencyCommand::Error.new(AgencyCommand::UNAUTHORIZED, code: :unauthorized)
    end

    payload
  end

  def self.expired?(payload)
    Time.iso8601(payload.fetch("expires_at")) <= Time.current
  end

  def self.fingerprint(fields)
    Digest::SHA256.hexdigest(fields.transform_keys(&:to_s).sort.to_h.to_json)
  end

  def self.candidate_digest(candidates)
    encoded = candidates.map { |candidate| "#{candidate.id}:#{Array(candidate.signals).sort.join(',')}" }.sort.join("|")
    Digest::SHA256.hexdigest(encoded)
  end

  def self.verifier
    Rails.application.message_verifier(:directory_duplicate_acknowledgement)
  end
end
