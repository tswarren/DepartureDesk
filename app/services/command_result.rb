class CommandResult
  attr_reader :status, :membership, :message

  def initialize(status:, membership: nil, message: nil)
    @status = status
    @membership = membership
    @message = message
  end

  def ok?
    %i[created replaced silent revoked accepted].include?(status)
  end

  def enqueue_mail?
    %i[created replaced].include?(status)
  end
end
