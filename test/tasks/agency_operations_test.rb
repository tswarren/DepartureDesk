require "test_helper"
require "rake"

class AgencyOperationsTaskTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks
    Rake::Task["agency:provision"].reenable
    @previous_env = ENV.to_h
  end

  teardown do
    ENV.replace(@previous_env)
  end

  test "provision task output contains identifiers and no secrets" do
    password = "task-password1"
    ENV.update(
      "AGENCY_OPERATOR" => "ops:task",
      "AGENCY_NAME" => "Task Provisioned Travel",
      "AGENCY_WORKSPACE_CODE" => "taskprov",
      "AGENCY_ADMIN_EMAIL" => "task-admin@example.com",
      "AGENCY_ADMIN_FIRST_NAME" => "Taylor",
      "AGENCY_ADMIN_LAST_NAME" => "Brooks",
      "AGENCY_ADMIN_PASSWORD" => password
    )

    output = capture_io { Rake::Task["agency:provision"].invoke }.first
    agency = Agency.find_by!(workspace_code: "taskprov")

    assert_includes output, "Agency ID: #{agency.id}"
    assert_includes output, "Workspace code: taskprov"
    assert_no_match(/#{Regexp.escape(password)}/, output)
    assert_no_match(/token/i, output)
    assert agency.agency_users.sole.authenticate(password)
  end
end
