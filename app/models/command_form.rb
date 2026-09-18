# frozen_string_literal: true

# ActiveModel error bag for command-object forms that do not wrap an AR record.
class CommandForm
  include ActiveModel::Model

  attr_reader :param_key

  def initialize(param_key:)
    @param_key = param_key.to_s
  end

  def model_name
    @model_name ||= ActiveModel::Name.new(self.class, nil, @param_key.camelize)
  end

  def add_message(attribute, message)
    errors.add(attribute, message)
  end

  def add_command_error(error, default_attribute: :base)
    attribute = map_attribute(error.message) || default_attribute
    errors.add(attribute, error.message)
  end

  private

  def map_attribute(message)
    text = message.to_s.downcase
    return :reason if text.include?("reason")
    return :channel if text.include?("channel")
    return :reference_note if text.include?("reference")
    return :display_value if text.include?("identifier")
    return :evidence_kind if text.include?("evidence kind")
    return :evidence_on if text.include?("evidence date") || text.include?("evidence on")
    return :booking_supplier_id if text.include?("booking supplier")
    return :target_kind if text.include?("scope") || text.include?("target")

    nil
  end
end
