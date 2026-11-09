# One way to show a refused command on a form (UX consolidation audit,
# finding C1): re-render the form with what was typed, put the message on
# the field it names, and list it in the summary at the top of the form
# (shared/form_errors). A message that names no field goes in the summary
# only. A command message is already a sentence, so it is marked refused:
# and shown as written.
module FormErrorRendering
  extend ActiveSupport::Concern

  private

  # fields: [attribute, label] pairs; a String label matches a message that
  # starts with it, a Regexp one anywhere in it. attribute: picks the
  # attribute from the message instead.
  def render_form_error(error, record, template, fields = [], attribute: nil, status: :unprocessable_entity)
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    add_refusal(record, error.message, attribute || form_error_attribute(error.message, fields))
    render template, status:
  end

  def add_refusal(record, message, attribute = :base)
    record.errors.add(attribute, message, refused: true)
  end

  def form_error_attribute(message, fields)
    field, = fields.find { |_field, label| label.is_a?(Regexp) ? label.match?(message) : message.start_with?(label) }
    field || :base
  end
end
