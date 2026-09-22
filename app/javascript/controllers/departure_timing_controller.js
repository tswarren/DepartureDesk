import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["mode", "targetFields", "exactFields"]

  connect() {
    this.update()
  }

  update() {
    const mode = this.selectedMode()
    if (this.hasTargetFieldsTarget) this.targetFieldsTarget.hidden = mode !== "target"
    if (this.hasExactFieldsTarget) this.exactFieldsTarget.hidden = mode !== "exact"
  }

  selectedMode() {
    const checked = this.modeTargets.find((input) => input.checked)
    return checked ? checked.value : "unknown"
  }
}
