# frozen_string_literal: true

# Slice 1 step 3a (SUP-06, S-12, ADR 0019 amendment): supplier quotes,
# agreements and confirmations kept with an arrangement. The file is in
# Active Storage; this row holds tenancy, kind, uploader and the SHA-256.
class CreateArrangementDocuments < ActiveRecord::Migration[8.1]
  def up
    create_table :arrangement_documents, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :supplier_arrangement_id, null: false
      table.string :kind, null: false
      table.string :description
      table.uuid :uploaded_by_id, null: false
      table.string :sha256, null: false
      table.timestamps

      table.index :supplier_arrangement_id
      table.check_constraint "kind IN ('quote', 'agreement', 'confirmation', 'other')", name: "arrangement_documents_kind"
      table.check_constraint "description IS NULL OR (btrim(description) <> '' AND char_length(description) <= 200)", name: "arrangement_documents_description"
      table.check_constraint "sha256 ~ '^[0-9a-f]{64}$'", name: "arrangement_documents_sha256"
    end
    add_foreign_key :arrangement_documents, :agencies, column: :agency_id, name: "fk_arrangement_documents_agency"
    execute <<~SQL
      ALTER TABLE arrangement_documents
        ADD CONSTRAINT fk_arrangement_documents_arrangement_same_agency
        FOREIGN KEY (supplier_arrangement_id, agency_id) REFERENCES supplier_arrangements (id, agency_id),
        ADD CONSTRAINT fk_arrangement_documents_uploader_same_agency
        FOREIGN KEY (uploaded_by_id, agency_id) REFERENCES agency_users (id, agency_id);
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
