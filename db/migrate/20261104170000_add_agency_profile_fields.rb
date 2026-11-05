# frozen_string_literal: true

# Slice 1 step 1 (SET-04 to SET-07, BKG-09, CMN-10): the client-facing agency
# profile, per-document inclusion flags and footers, the hold duration and
# the installment buffer. agencies.name stays the display name.
class AddAgencyProfileFields < ActiveRecord::Migration[8.1]
  FAMILIES = %w[confirmation invoice receipt statement].freeze

  def up
    change_table :agencies, bulk: true do |table|
      table.string :contact_email
      table.string :agency_contact_name
      table.string :phone_number
      table.string :phone_normalized_number
      table.string :phone_extension
      table.string :phone_country_code
      table.string :address_line_1
      table.string :address_line_2
      table.string :address_locality
      table.string :address_region
      table.string :address_postal_code
      table.string :address_country_code
      table.text :seller_of_travel_disclosure
      table.text :confirmation_footer
      table.text :financial_document_footer
      table.integer :hold_duration_days, null: false, default: 2
      table.integer :installment_buffer_days, null: false, default: 14
    end

    add_check_constraint :agencies, "contact_email IS NULL OR contact_email = lower(btrim(contact_email))", name: "agencies_contact_email_normalized"
    add_check_constraint :agencies, "phone_number IS NULL OR (phone_normalized_number IS NOT NULL AND phone_normalized_number ~ '^\\+[1-9][0-9]{0,14}$' AND phone_country_code IS NOT NULL AND phone_country_code ~ '^[A-Z]{2}$')", name: "agencies_phone_complete"
    add_check_constraint :agencies, "phone_extension IS NULL OR phone_number IS NOT NULL", name: "agencies_phone_extension_needs_number"
    add_check_constraint :agencies, <<~SQL.squish, name: "agencies_address_complete"
      (address_line_1 IS NULL AND address_line_2 IS NULL AND address_locality IS NULL
        AND address_region IS NULL AND address_postal_code IS NULL AND address_country_code IS NULL)
      OR (address_line_1 IS NOT NULL AND btrim(address_line_1) <> ''
        AND address_country_code IS NOT NULL AND address_country_code ~ '^[A-Z]{2}$')
    SQL
    add_check_constraint :agencies, "hold_duration_days >= 1", name: "agencies_hold_duration_positive"
    add_check_constraint :agencies, "installment_buffer_days >= 0", name: "agencies_installment_buffer_nonnegative"

    create_table :agency_document_inclusions, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true, index: false
      table.string :document_family, null: false
      table.boolean :include_display_name, null: false
      table.boolean :include_contact_email, null: false
      table.boolean :include_phone, null: false
      table.boolean :include_legal_name, null: false
      table.boolean :include_mailing_address, null: false
      table.boolean :include_agency_contact_name, null: false
      table.boolean :include_seller_of_travel_disclosure, null: false
      table.boolean :include_footer, null: false
      table.timestamps

      table.index %i[agency_id document_family], unique: true, name: "index_agency_document_inclusions_on_agency_family"
      table.check_constraint "document_family IN (#{FAMILIES.map { |family| quote(family) }.join(", ")})",
        name: "agency_document_inclusions_family_valid"
    end

    # SET-06 and SET-07 defaults for agencies that already exist.
    execute <<~SQL
      INSERT INTO agency_document_inclusions (
        agency_id, document_family, include_display_name, include_contact_email, include_phone,
        include_legal_name, include_mailing_address, include_agency_contact_name,
        include_seller_of_travel_disclosure, include_footer, created_at, updated_at
      )
      SELECT agencies.id, families.family, true, true, true,
        families.family <> 'confirmation', families.family <> 'confirmation', false,
        false, true, now(), now()
      FROM agencies
      CROSS JOIN (VALUES #{FAMILIES.map { |family| "(#{quote(family)})" }.join(", ")}) AS families (family)
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
