ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    def invite_offices(agency = agencies(:one))
      office = agency.offices.active.order(:created_at).first
      { office_ids: [ office.id ], default_office_id: office.id }
    end

    def create_person!(agency, given_name: "Given", family_name: "Family", preferred_name: nil, **profile)
      person = Person.new(agency:, given_name:, family_name:, preferred_name:, **profile)
      party = agency.parties.new(party_kind: "person", status: "active")
      party.apply_derived_names!(person)
      party.save!
      person.party = party
      person.party_id = party.id
      person.save!
      person
    end
  end
end

class AmbiguousMembershipRelation
  def initialize(memberships)
    @memberships = memberships
  end

  def includes(*)
    self
  end

  def limit(*)
    self
  end

  def to_a
    @memberships
  end
end
