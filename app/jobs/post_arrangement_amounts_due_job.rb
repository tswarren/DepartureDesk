class PostArrangementAmountsDueJob < ApplicationJob
  queue_as :supplier_money

  retry_on ActiveRecord::Deadlocked, ActiveRecord::SerializationFailure, ActiveRecord::LockWaitTimeout,
    attempts: 5, wait: :polynomially_longer

  def perform(agency_id:, arrangement_id:)
    agency = Agency.find_by(id: agency_id)
    return if agency.nil? || !agency.active?

    arrangement = agency.supplier_arrangements.find_by(id: arrangement_id)
    return if arrangement.nil?

    PostArrangementAmountsDue.new(agency:, arrangement:).call
  end
end
