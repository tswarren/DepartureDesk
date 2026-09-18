# frozen_string_literal: true

# Exact-version definition rows are mutable only while their Arrangement version is draft.
module DraftVersionDefinition
  extend ActiveSupport::Concern

  included do
    validate :version_must_be_draft_for_definition_mutation
    before_destroy :reject_non_draft_definition_destroy
  end

  private

  def version_must_be_draft_for_definition_mutation
    version = supplier_arrangement_version
    return if version.nil?
    return if version.draft?

    errors.add(:base, "Exact-version definitions are immutable after leaving draft")
  end

  def reject_non_draft_definition_destroy
    version = supplier_arrangement_version
    return if version.nil? || version.draft?

    errors.add(:base, "Exact-version definitions are immutable after leaving draft")
    throw :abort
  end
end
