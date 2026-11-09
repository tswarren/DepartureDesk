# A draft booking's proposed installment (CMN-09; step 8 plan, question 1):
# proposed from its terms version's payment schedule, which staff may
# adjust before acceptance. Replaced whole when proposed afresh. The
# client's acceptance covers them, and confirmation makes the charge's
# installments from them.
class InstallmentProposal < ApplicationRecord
  DUE_KINDS = %w[at_confirmation on_date].freeze

  belongs_to :agency
  belongs_to :client_booking, inverse_of: :installment_proposals

  validates :due_kind, inclusion: { in: DUE_KINDS }
  validates :amount_minor_units, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def at_confirmation? = due_kind == "at_confirmation"
end
