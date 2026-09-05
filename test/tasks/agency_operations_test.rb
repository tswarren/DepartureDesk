require "test_helper"
require "rake"

class AgencyOperationsTaskTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    Rails.application.load_tasks
    Rake::Task["agency:provision"].reenable
    @previous_env = captured_env
  end

  teardown do
    restore_env(@previous_env)
  end

  test "provision task output contains identifiers and no secrets" do
    ENV.update(
      "AGENCY_PROVISIONING_KEY" => "task-key-#{SecureRandom.hex(4)}",
      "AGENCY_OPERATOR" => "ops:task",
      "AGENCY_NAME" => "Task Provisioned Travel",
      "AGENCY_ADMIN_EMAIL" => "task-admin-#{SecureRandom.hex(4)}@example.com",
      "AGENCY_ADMIN_FIRST_NAME" => "Taylor",
      "AGENCY_ADMIN_LAST_NAME" => "Brooks"
    )

    output = nil
    assert_enqueued_emails 1 do
      output = capture_io { Rake::Task["agency:provision"].invoke }.first
    end

    agency = Agency.find_by!(name: "Task Provisioned Travel")
    membership = agency.agency_memberships.sole

    assert_includes output, "Agency ID: #{agency.id}"
    assert_includes output, "Membership ID: #{membership.id}"
    assert_includes output, "Next: the invited administrator must accept the invitation email."
    assert_no_match(/password/i, output)
    assert_no_match(/token/i, output)
    assert_no_match(membership.invitation_token, output)
  end

  private

  def captured_env
    %w[
      AGENCY_PROVISIONING_KEY
      AGENCY_OPERATOR
      AGENCY_NAME
      AGENCY_LEGAL_NAME
      AGENCY_COUNTRY_CODE
      AGENCY_TIMEZONE
      AGENCY_CURRENCY
      AGENCY_ADMIN_EMAIL
      AGENCY_ADMIN_FIRST_NAME
      AGENCY_ADMIN_LAST_NAME
      AGENCY_ADMIN_PREFERRED_NAME
    ].to_h { |key| [ key, ENV[key] ] }
  end

  def restore_env(previous)
    previous.each do |key, value|
      if value.nil?
        ENV.delete(key)
      else
        ENV[key] = value
      end
    end
  end
end
