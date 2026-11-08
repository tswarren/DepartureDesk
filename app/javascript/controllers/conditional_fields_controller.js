import { Controller } from "@hotwired/stimulus"

// Shows only the fields a choice makes relevant: each option target names
// the radio values it belongs to in data-show-for, and is hidden and
// disabled, so it isn't submitted, while another value is chosen.
export default class extends Controller {
  static targets = ["option"]

  connect() {
    this.update()
  }

  update() {
    const checked = this.element.querySelector("input[type=radio][data-conditional-fields-source]:checked")
    const value = checked ? checked.value : null
    this.optionTargets.forEach((option) => {
      const show = option.dataset.showFor.split(" ").includes(value)
      option.hidden = !show
      option.querySelectorAll("input, select, textarea").forEach((field) => { field.disabled = !show })
    })
  }
}
