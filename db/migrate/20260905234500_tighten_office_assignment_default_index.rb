class TightenOfficeAssignmentDefaultIndex < ActiveRecord::Migration[8.1]
  def up
    remove_index :office_assignments, name: "index_office_assignments_one_default_per_membership"
    add_index :office_assignments,
      :agency_membership_id,
      unique: true,
      where: "is_default = TRUE AND status = 'active'",
      name: "index_office_assignments_one_default_per_membership"
  end

  def down
    remove_index :office_assignments, name: "index_office_assignments_one_default_per_membership"
    add_index :office_assignments,
      :agency_membership_id,
      unique: true,
      where: "is_default = TRUE",
      name: "index_office_assignments_one_default_per_membership"
  end
end
