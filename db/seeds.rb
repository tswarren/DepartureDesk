if Rails.env.development?
    seed_user = User.find_or_initialize_by(
      email_address: "email@example.com"
    )

    seed_user.assign_attributes(
      password: "ChangeMe123!",
      password_confirmation: "ChangeMe123!"
    )

    seed_user.save!

    puts "Seed user ready:"
    puts "  Email: #{seed_user.email_address}"
    puts "  ID: #{seed_user.id}"
end
