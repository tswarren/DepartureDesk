class AddSupplierCategoriesAndDefaults < ActiveRecord::Migration[8.1]
  NOTE_LIMIT = 2000
  CATEGORY_CODES = %w[
    accommodation
    air
    cruise
    rail
    ground_transportation
    tour_operator
    activity
    venue
    dining
    insurance
    destination_management
  ].freeze

  def up
    add_column :supplier_profiles, :payment_term_notes, :text
    add_column :supplier_profiles, :commission_notes, :text
    add_column :supplier_profiles, :booking_instructions, :text
    add_column :supplier_profiles, :payment_instructions, :text
    add_column :supplier_profiles, :cancellation_policy_notes, :text
    add_column :supplier_profiles, :portal_url, :string

    %w[
      payment_term_notes
      commission_notes
      booking_instructions
      payment_instructions
      cancellation_policy_notes
    ].each do |column|
      add_check_constraint :supplier_profiles,
        "char_length(#{column}) <= #{NOTE_LIMIT}",
        name: "supplier_profiles_#{column}_length"
    end
    add_check_constraint :supplier_profiles,
      "portal_url IS NULL OR (portal_url ~ '^https://' AND portal_url !~ '^https://[^/]*@')",
      name: "supplier_profiles_portal_url_https"

    create_table :supplier_service_category_assignments,
      id: :uuid,
      default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :supplier_profile_id, null: false
      table.string :category_code, null: false
      table.timestamps null: false
    end

    add_index :supplier_service_category_assignments,
      [ :id, :agency_id ],
      unique: true,
      name: "index_ssca_on_id_and_agency_id"
    add_index :supplier_service_category_assignments,
      [ :agency_id, :supplier_profile_id, :category_code ],
      unique: true,
      name: "index_ssca_on_profile_and_category"
    add_check_constraint :supplier_service_category_assignments,
      "category_code IN (#{CATEGORY_CODES.map { |code| "'#{code}'" }.join(", ")})",
      name: "ssca_category_code_valid"

    execute <<~SQL
      ALTER TABLE supplier_service_category_assignments
        ADD CONSTRAINT ssca_profile_same_agency_fk
        FOREIGN KEY (supplier_profile_id, agency_id)
        REFERENCES supplier_profiles (id, agency_id);
    SQL
  end

  def down
    execute <<~SQL
      ALTER TABLE supplier_service_category_assignments
        DROP CONSTRAINT IF EXISTS ssca_profile_same_agency_fk;
    SQL
    drop_table :supplier_service_category_assignments
    remove_check_constraint :supplier_profiles, name: "supplier_profiles_portal_url_https"
    %w[
      cancellation_policy_notes
      payment_instructions
      booking_instructions
      commission_notes
      payment_term_notes
    ].each do |column|
      remove_check_constraint :supplier_profiles, name: "supplier_profiles_#{column}_length"
    end
    remove_column :supplier_profiles, :portal_url
    remove_column :supplier_profiles, :cancellation_policy_notes
    remove_column :supplier_profiles, :payment_instructions
    remove_column :supplier_profiles, :booking_instructions
    remove_column :supplier_profiles, :commission_notes
    remove_column :supplier_profiles, :payment_term_notes
  end
end
