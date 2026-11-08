import { Controller } from "@hotwired/stimulus"

// The add-group form's presets: a kind fills in the service category and
// representation, and only the fields that representation and promise use
// are shown. Hidden fields are disabled, so they aren't submitted.
export default class extends Controller {
  static targets = ["category", "representation", "promise", "quantity", "shellOnly"]
  static values = { presets: Object }

  connect() {
    this.refresh()
  }

  choose(event) {
    const preset = this.presetsValue[event.target.value]
    if (preset) {
      this.categoryTarget.value = preset.service_category
      this.representationTarget.value = preset.representation
    }
    this.refresh()
  }

  refresh() {
    const shells = this.representationTarget.value === "unit_shells"
    const counted = this.representationTarget.value !== "none" && !["on_request", "rate_only"].includes(this.promiseTarget.value)
    this.toggle(this.quantityTargets, counted)
    this.toggle(this.shellOnlyTargets, shells)
  }

  toggle(targets, show) {
    targets.forEach((target) => {
      target.hidden = !show
      target.querySelectorAll("input, select").forEach((field) => { field.disabled = !show })
    })
  }
}
