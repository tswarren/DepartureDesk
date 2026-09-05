class IssuePasswordReset
  def initialize(user:)
    @user = user
  end

  def call
    User.transaction do
      @user.lock!
      @user.increment!(:password_reset_version)
      DeliveryIntent.record!(
        agency: @user.usable_agency_membership&.agency,
        subject: @user,
        purpose: "password_reset",
        version: @user.password_reset_version
      )
    end
  end
end
