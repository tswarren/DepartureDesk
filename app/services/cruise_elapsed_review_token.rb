# frozen_string_literal: true

# Proves Staff were shown a specific elapsed-requirement set on the Cruise activation review.
# The activation command cannot tell a reviewed checkbox from a forged boolean.
class CruiseElapsedReviewToken
  PURPOSE = "cruise.elapsed_review"

  def self.issue(agency_id:, arrangement_version_id:, elapsed_definition_ids:)
    verifier.generate(
      {
        "agency_id" => agency_id.to_s,
        "arrangement_version_id" => arrangement_version_id.to_s,
        "elapsed_definition_ids" => elapsed_definition_ids.map(&:to_s).sort
      },
      purpose: PURPOSE
    )
  end

  def self.read(token)
    return nil if token.blank?

    verifier.verified(token.to_s, purpose: PURPOSE)
  end

  def self.verifier
    Rails.application.message_verifier(:cruise_elapsed_review)
  end
end
