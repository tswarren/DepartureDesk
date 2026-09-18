require "test_helper"

class CommandFormTest < ActiveSupport::TestCase
  test "adds command errors onto attributes for summary links" do
    form = CommandForm.new(param_key: "confirmation")
    form.add_command_error(AgencyCommand::Error.new("Choose evidence kind.", code: :invalid))
    assert form.errors[:evidence_kind].any?
    assert_equal "confirmation", form.model_name.param_key
  end
end
