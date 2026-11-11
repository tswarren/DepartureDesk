# The Alpha fixture in its own agency, for the demonstration cases and the
# screens built on it. The agency keeps time in America/New_York, as the
# fixture's deadlines assume (SET-10, B9).
module AlphaScenario
  Result = Data.define(:agency, :actor, :baseline_staff, :alpha)

  def self.load!(confirm_cruise: true, bookings: :none)
    scenario = M1DirectoryScenario.empty
    scenario.agency.update_columns(default_timezone: AlphaFixture::TIME_ZONE)
    alpha = AlphaFixture.load!(agency: scenario.agency.reload, actor: scenario.actor, confirm_cruise:, bookings:, reseller_password: M1DirectoryScenario::PASSWORD)
    Result.new(agency: scenario.agency, actor: scenario.actor, baseline_staff: scenario.baseline_staff, alpha:)
  end

  def self.cleanup!(result)
    M2DepartureScenario.cleanup!(result&.agency)
  end
end
