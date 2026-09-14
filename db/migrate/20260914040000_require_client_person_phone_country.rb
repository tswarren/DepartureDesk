class RequireClientPersonPhoneCountry < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE client_person_phone_numbers AS phones
      SET country_code = agencies.country_code
      FROM agencies
      WHERE phones.agency_id = agencies.id
        AND (phones.country_code IS NULL OR btrim(phones.country_code) = '')
    SQL

    change_column_null :client_person_phone_numbers, :country_code, false
    remove_check_constraint :client_person_phone_numbers, name: "client_person_phone_numbers_country_shape"
    add_check_constraint :client_person_phone_numbers,
      "country_code ~ '^[A-Z]{2}$'",
      name: "client_person_phone_numbers_country_shape"
  end

  def down
    change_column_null :client_person_phone_numbers, :country_code, true
    remove_check_constraint :client_person_phone_numbers, name: "client_person_phone_numbers_country_shape"
    add_check_constraint :client_person_phone_numbers,
      "country_code IS NULL OR country_code ~ '^[A-Z]{2}$'",
      name: "client_person_phone_numbers_country_shape"
  end
end
