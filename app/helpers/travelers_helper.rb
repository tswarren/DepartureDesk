module TravelersHelper
  GENDER_LABELS = { "female" => "Female", "male" => "Male", "unspecified" => "Unspecified (X)" }.freeze

  def traveler_gender_label(traveler) = GENDER_LABELS[traveler.gender] || "Not recorded"

  def traveler_date_of_birth(traveler)
    traveler.date_of_birth ? traveler.date_of_birth.to_fs(:long) : "Not recorded"
  end
end
