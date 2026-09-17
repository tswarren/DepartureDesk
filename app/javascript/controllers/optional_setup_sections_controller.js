import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "occurrenceCheckbox",
    "occurrenceFields",
    "resourceCheckbox",
    "resourceFields"
  ]

  connect() {
    this.update()
  }

  update() {
    this.occurrenceFieldsTarget.hidden = !this.occurrenceCheckboxTarget.checked
    this.resourceFieldsTarget.hidden = !this.resourceCheckboxTarget.checked
    this.occurrenceCheckboxTarget.setAttribute("aria-expanded", this.occurrenceCheckboxTarget.checked)
    this.resourceCheckboxTarget.setAttribute("aria-expanded", this.resourceCheckboxTarget.checked)
  }
}
