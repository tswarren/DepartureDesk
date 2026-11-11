# frozen_string_literal: true

# Slice 1 step 10 (DOC-01, DOC-11, DOC-21, D13; ADR 0019): issued documents
# as append-only versions, each with its PDF in Active Storage and a snapshot
# of the values it shows, and the manual deliveries recorded against them.
class CreateDocumentVersions < ActiveRecord::Migration[8.1]
  def up
    add_index :receipts, %i[id agency_id], unique: true, name: "index_receipts_on_id_and_agency_id"

    create_table :document_versions, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.string :document_type, null: false
      table.string :number, null: false
      table.integer :version_number, null: false, default: 1
      table.uuid :client_booking_id
      table.uuid :receipt_id
      table.uuid :supersedes_id
      table.text :reissue_reason
      table.datetime :issued_at, null: false
      table.uuid :issued_by_id, null: false
      table.string :template_version, null: false
      table.string :renderer_version, null: false
      table.string :sha256, null: false
      table.jsonb :snapshot, null: false
      table.timestamps

      table.index %i[id agency_id], unique: true, name: "index_document_versions_on_id_and_agency_id"
      table.index %i[agency_id document_type number version_number], unique: true, name: "index_document_versions_on_number"
      # Slice 1 issues each document once; a reissue (DOC-12) is Slice 1b.
      table.index %i[client_booking_id document_type], unique: true, where: "supersedes_id IS NULL AND client_booking_id IS NOT NULL", name: "index_document_versions_one_per_booking"
      table.index :receipt_id, unique: true, where: "supersedes_id IS NULL AND receipt_id IS NOT NULL", name: "index_document_versions_one_per_receipt"
      table.check_constraint "document_type IN ('confirmation', 'invoice', 'receipt')", name: "document_versions_type"
      table.check_constraint "(document_type = 'receipt') = (receipt_id IS NOT NULL) AND (document_type = 'receipt') = (client_booking_id IS NULL)", name: "document_versions_subject"
      table.check_constraint "number ~ (CASE document_type WHEN 'confirmation' THEN '^CNF-' WHEN 'invoice' THEN '^INV-' ELSE '^RCP-' END || '[0-9]{5,}$')", name: "document_versions_number_format"
      table.check_constraint "version_number >= 1 AND (supersedes_id IS NULL) = (version_number = 1) AND (supersedes_id IS NULL) = (reissue_reason IS NULL)", name: "document_versions_reissue"
      table.check_constraint "sha256 ~ '^[0-9a-f]{64}$'", name: "document_versions_sha256"
      table.check_constraint "jsonb_typeof(snapshot) = 'object'", name: "document_versions_snapshot"
    end

    create_table :document_deliveries, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :document_version_id, null: false
      table.string :delivery_method, null: false
      table.string :recipient, null: false
      table.date :delivered_on, null: false
      table.uuid :recorded_by_id, null: false
      table.datetime :recorded_at, null: false

      table.index :document_version_id, name: "index_document_deliveries_on_version"
      table.check_constraint "delivery_method IN ('own_email', 'printed', 'in_person')", name: "document_deliveries_method"
      table.check_constraint "length(btrim(recipient)) BETWEEN 1 AND 200", name: "document_deliveries_recipient"
    end

    execute <<~SQL
      ALTER TABLE document_versions
        ADD CONSTRAINT fk_document_versions_agency FOREIGN KEY (agency_id) REFERENCES agencies (id),
        ADD CONSTRAINT fk_document_versions_booking_same_agency FOREIGN KEY (client_booking_id, agency_id) REFERENCES client_bookings (id, agency_id),
        ADD CONSTRAINT fk_document_versions_receipt_same_agency FOREIGN KEY (receipt_id, agency_id) REFERENCES receipts (id, agency_id),
        ADD CONSTRAINT fk_document_versions_supersedes_same_agency FOREIGN KEY (supersedes_id, agency_id) REFERENCES document_versions (id, agency_id),
        ADD CONSTRAINT fk_document_versions_issuer_same_agency FOREIGN KEY (issued_by_id, agency_id) REFERENCES agency_users (id, agency_id);
      ALTER TABLE document_deliveries
        ADD CONSTRAINT fk_document_deliveries_agency FOREIGN KEY (agency_id) REFERENCES agencies (id),
        ADD CONSTRAINT fk_document_deliveries_version_same_agency FOREIGN KEY (document_version_id, agency_id) REFERENCES document_versions (id, agency_id),
        ADD CONSTRAINT fk_document_deliveries_recorder_same_agency FOREIGN KEY (recorded_by_id, agency_id) REFERENCES agency_users (id, agency_id);

      -- DOC-11, ADR 0019: an issued version never changes. Active Storage may
      -- touch updated_at when the PDF is attached; nothing else is written.
      CREATE FUNCTION public.reject_document_version_mutation() RETURNS trigger
          LANGUAGE plpgsql AS $$
      BEGIN
        IF TG_OP = 'UPDATE' AND (to_jsonb(NEW) - 'updated_at') = (to_jsonb(OLD) - 'updated_at') THEN
          RETURN NEW;
        END IF;
        RAISE EXCEPTION 'document_versions rows are append-only';
      END;
      $$;
      CREATE TRIGGER document_versions_reject_mutation BEFORE DELETE OR UPDATE ON public.document_versions
        FOR EACH ROW EXECUTE FUNCTION public.reject_document_version_mutation();

      CREATE FUNCTION public.reject_document_delivery_mutation() RETURNS trigger
          LANGUAGE plpgsql AS $$
      BEGIN
        RAISE EXCEPTION 'document_deliveries rows are append-only';
      END;
      $$;
      CREATE TRIGGER document_deliveries_reject_mutation BEFORE DELETE OR UPDATE ON public.document_deliveries
        FOR EACH ROW EXECUTE FUNCTION public.reject_document_delivery_mutation();

      -- ADR 0019: an issued version's PDF is never detached, replaced or purged.
      CREATE FUNCTION public.reject_document_attachment_change() RETURNS trigger
          LANGUAGE plpgsql AS $$
      BEGIN
        IF OLD.record_type = 'DocumentVersion' THEN
          RAISE EXCEPTION 'an issued document''s PDF cannot be removed or replaced';
        END IF;
        RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
      END;
      $$;
      CREATE TRIGGER active_storage_attachments_keep_documents BEFORE DELETE OR UPDATE ON public.active_storage_attachments
        FOR EACH ROW EXECUTE FUNCTION public.reject_document_attachment_change();
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
