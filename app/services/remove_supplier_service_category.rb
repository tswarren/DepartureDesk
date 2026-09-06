class RemoveSupplierServiceCategory < RoleProfileCommand
  def initialize(agency:, party:, profile:, category_code:, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @party = party
    @profile = profile
    @category_code = category_code.to_s
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    with_directory_locks(@agency, parties: [ @party ], records: [ @profile ]) { perform }
  end

  private

  def profile_association
    :supplier_profile
  end

  def role_noun
    "supplier"
  end

  def perform
    ensure_profile_on_party!(@party, @profile)
    assignment = @profile.service_category_assignments.find_by(category_code: @category_code)
    unless assignment
      raise Error.new("That service category is not assigned.", code: :not_found)
    end

    audit!(
      agency: @agency,
      action: "directory.supplier_service_category_removed",
      subject: assignment,
      details: {
        "party_id" => @profile.party_id,
        "supplier_profile_id" => @profile.id,
        "category_code" => assignment.category_code
      },
      **actor_audit_args
    )
    assignment.destroy!
    profile_result(:accepted, @party, @profile)
  end
end
