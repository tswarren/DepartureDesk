module ApplicationHelper
  def status_badge(status, modifier:)
    tag.span status, class: "dd-badge dd-badge--#{modifier}"
  end

  def office_status_badge(office)
    status_badge(office.status, modifier: office.active? ? "success" : "neutral")
  end
end
