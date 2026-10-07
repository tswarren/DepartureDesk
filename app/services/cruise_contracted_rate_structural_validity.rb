# frozen_string_literal: true

class CruiseContractedRateStructuralValidity
  include CostCommandSupport

  def initialize(agency:, definition:)
    @agency = agency
    @definition = definition
  end

  def call
    validate_ready!(@definition, require_usage: false)
    true
  rescue AgencyCommand::Error, ActiveRecord::RecordInvalid
    false
  end
end
