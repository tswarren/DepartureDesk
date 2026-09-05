class ReactivateMembership < MembershipCommand
  def initialize(agency:, membership:, actor: nil, actor_identifier: nil, privileged: false, after_lock: nil)
    @agency = agency
    @membership = membership
    @after_lock = after_lock
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    before_activation
    ActivateMembership.new(
      agency: @agency,
      membership: @membership,
      mode: :reactivate,
      actor: @actor,
      actor_identifier: @actor_identifier,
      privileged: @privileged,
      after_lock: @after_lock
    ).call
  end

  private

  def before_activation
  end
end
