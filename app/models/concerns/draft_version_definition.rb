# frozen_string_literal: true

# Exact-version definition rows are mutable only while their parent version is draft.
module DraftVersionDefinition
  extend ActiveSupport::Concern

  included do
    class_attribute :draft_parent_version_association, instance_writer: false
    self.draft_parent_version_association = :supplier_arrangement_version

    validate :version_must_be_draft_for_definition_mutation
    before_destroy :reject_non_draft_definition_destroy
  end

  class_methods do
    def guards_draft_version(association)
      self.draft_parent_version_association = association
    end
  end

  private

  def draft_parent_version
    public_send(self.class.draft_parent_version_association)
  end

  def version_must_be_draft_for_definition_mutation
    version = draft_parent_version
    return if version.nil?
    return if version.draft?

    errors.add(:base, "Exact-version definitions are immutable after leaving draft")
  end

  def reject_non_draft_definition_destroy
    version = draft_parent_version
    return if version.nil? || version.draft?

    errors.add(:base, "Exact-version definitions are immutable after leaving draft")
    throw :abort
  end
end
