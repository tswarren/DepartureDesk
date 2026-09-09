class CommandResult
  attr_reader :status, :membership, :office, :assignment, :party, :message, :contact_point, :purpose_assignment, :relationship, :note, :client_profile, :supplier_profile, :duplicate_match, :travel_program, :departure, :supplier_arrangement, :supplier_reservation, :supplier_resource, :supplier_service_occurrence, :supplier_confirmation, :supplier_cost_term, :supplier_commitment, :supplier_deposit_requirement, :supplier_clause, :supplier_clause_preview, :supplier_deadline, :supplier_capacity_position, :supplier_capacity_event

  def initialize(status:, membership: nil, office: nil, assignment: nil, party: nil, message: nil, contact_point: nil, purpose_assignment: nil, relationship: nil, note: nil, client_profile: nil, supplier_profile: nil, duplicate_match: nil, travel_program: nil, departure: nil, supplier_arrangement: nil, supplier_reservation: nil, supplier_resource: nil, supplier_service_occurrence: nil, supplier_confirmation: nil, supplier_cost_term: nil, supplier_commitment: nil, supplier_deposit_requirement: nil, supplier_clause: nil, supplier_clause_preview: nil, supplier_deadline: nil, supplier_capacity_position: nil, supplier_capacity_event: nil)
    @status = status
    @membership = membership
    @office = office
    @assignment = assignment
    @party = party
    @message = message
    @contact_point = contact_point
    @purpose_assignment = purpose_assignment
    @relationship = relationship
    @note = note
    @client_profile = client_profile
    @supplier_profile = supplier_profile
    @duplicate_match = duplicate_match
    @travel_program = travel_program
    @departure = departure
    @supplier_arrangement = supplier_arrangement
    @supplier_reservation = supplier_reservation
    @supplier_resource = supplier_resource
    @supplier_service_occurrence = supplier_service_occurrence
    @supplier_confirmation = supplier_confirmation
    @supplier_cost_term = supplier_cost_term
    @supplier_commitment = supplier_commitment
    @supplier_deposit_requirement = supplier_deposit_requirement
    @supplier_clause = supplier_clause
    @supplier_clause_preview = supplier_clause_preview
    @supplier_deadline = supplier_deadline
    @supplier_capacity_position = supplier_capacity_position
    @supplier_capacity_event = supplier_capacity_event
  end

  def ok?
    %i[created replaced silent revoked accepted].include?(status)
  end

  def enqueue_mail?
    %i[created replaced].include?(status)
  end
end
