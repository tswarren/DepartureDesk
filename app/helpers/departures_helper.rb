module DeparturesHelper
  # A DepartureSummary::Space in words: "7 of 8 left", or why there is no count.
  def space_left_label(space)
    case space.note
    when nil then "#{space.left} of #{space.total} left"
    when :planned then "#{space.total || "?"} planned"
    when :on_request then "On request"
    else "No count kept"
    end
  end
end
