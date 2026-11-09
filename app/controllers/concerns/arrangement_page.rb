# The arrangement's sub-pages (UX consolidation audit B1, decision 3): each
# loads the arrangement through the Departure and shows one part of it under
# the shared header and section tabs.
module ArrangementPage
  extend ActiveSupport::Concern
  include ArrangementAccess

  included do
    before_action :require_arrangement_view!
    before_action :set_departure
    before_action :set_arrangement
  end
end
