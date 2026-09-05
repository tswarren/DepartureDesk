class SelectCurrentOffice
  class Error < StandardError
    attr_reader :code

    def initialize(message, code: :unauthorized)
      super(message)
      @code = code
    end
  end

  def initialize(session:, office:)
    @session = session
    @office = office
  end

  def call
    membership = @session.user.usable_agency_membership
    raise Error.new("You are not authorized to do that.") unless membership

    @office.lock!
    @office.reload

    unless @office.agency_id == membership.agency_id && membership.can_access_office?(@office)
      raise Error.new("You are not authorized to do that.")
    end

    @session.update!(office: @office)
    @office
  end
end
