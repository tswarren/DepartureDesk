class AssignSupplierServiceCategory < RoleProfileCommand
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
    unless @profile.active?
      raise Error.new("Inactive roles cannot change service categories until they are reactivated.", code: :invalid)
    end
    unless SupplierServiceCategoryAssignment::CATEGORY_CODES.include?(@category_code)
      raise Error.new("Choose a supplier service category.", code: :invalid)
    end

    assignment = SupplierServiceCategoryAssignment.create!(
      agency: @agency,
      supplier_profile: @profile,
      category_code: @category_code
    )
    audit!(
      agency: @agency,
      action: "directory.supplier_service_category_assigned",
      subject: assignment,
      details: {
        "party_id" => @profile.party_id,
        "supplier_profile_id" => @profile.id,
        "category_code" => assignment.category_code
      },
      **actor_audit_args
    )
    profile_result(:created, @party, @profile)
  end
end
