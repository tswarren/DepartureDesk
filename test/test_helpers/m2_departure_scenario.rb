module M2DepartureScenario
  Result = Data.define(
    :directory,
    :departure,
    :fixture_operating_currency,
    :fixture_time_zone,
    :fixture_default_task_owner
  )

  CELEBRITY_NAME = "Celebrity Beyond"
  CELEBRITY_STARTS_ON = Date.new(2027, 11, 6)
  CELEBRITY_ENDS_ON = Date.new(2027, 11, 13)
  VINEYARD_NAME = "Vineyard Tour"
  VINEYARD_STARTS_ON = Date.new(2027, 6, 5)
  VINEYARD_ENDS_ON = Date.new(2027, 6, 7)

  def self.celebrity(suffix: M1DirectoryScenario.unique_suffix)
    wrap(M1DirectoryScenario.celebrity(suffix:), name: CELEBRITY_NAME, starts_on: CELEBRITY_STARTS_ON, ends_on: CELEBRITY_ENDS_ON)
  end

  def self.vineyard(suffix: M1DirectoryScenario.unique_suffix)
    wrap(M1DirectoryScenario.vineyard(suffix:), name: VINEYARD_NAME, starts_on: VINEYARD_STARTS_ON, ends_on: VINEYARD_ENDS_ON)
  end

  def self.isolation_companion(primary)
    wrap(
      M1DirectoryScenario.isolation_companion(primary.directory),
      name: "#{CELEBRITY_NAME} Isolation",
      starts_on: CELEBRITY_STARTS_ON,
      ends_on: CELEBRITY_ENDS_ON
    )
  end

  def self.cleanup!(*results)
    agencies = results.flatten.compact.map { |result| agency_from(result) }.uniq
    agencies.each do |agency|
      Departure.transaction do
        # Decision history is append-only (DEP-19); replica mode skips that trigger for test cleanup only.
        ActiveRecord::Base.connection.execute("SET LOCAL session_replication_role = replica")
        # Tasks, arrangements and their inventory (step 3); events and frozen rates are append-only too.
        [ Task, SupplierDeadline, CapacityProjection, CapacityEvent, UnitShell, CapacityPool, SupplierRateLine, CapacityRule,
          ArrangementDocument, InventoryGroup, SupplierArrangement, PayeeAccount ].each { |model| model.where(agency_id: agency.id).delete_all }
        DepartureDecision.where(agency_id: agency.id).delete_all
        DepartureTeamMember.where(agency_id: agency.id).delete_all
        Departure.where(agency_id: agency.id).delete_all
      end
    end
    M1DirectoryScenario.cleanup!(*agencies)
  end

  def self.wrap(directory, name:, starts_on:, ends_on:)
    # Fixture-only operating facts copied from the M1 Agency and actor; not scenario-document claims.
    currency = directory.agency.default_currency
    time_zone = directory.agency.default_timezone
    actor = directory.actor
    departure = CreateDeparture.new(
      agency: directory.agency,
      actor:,
      attributes: {
        name:,
        starts_on:,
        ends_on:,
        time_zone:,
        operating_currency: currency
      }
    ).call.record

    Result.new(
      directory:,
      departure:,
      fixture_operating_currency: currency,
      fixture_time_zone: time_zone,
      fixture_default_task_owner: actor
    )
  end
  private_class_method :wrap

  def self.agency_from(result)
    return result.directory.agency if result.respond_to?(:directory)
    return result.agency if result.respond_to?(:agency)

    result
  end
  private_class_method :agency_from
end
