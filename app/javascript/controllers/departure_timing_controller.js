import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["mode", "targetFields", "exactFields", "targetInput", "startsOn", "endsOn"]

  connect() {
    this.update()
  }

  update() {
    const mode = this.selectedMode()
    this.targetFieldsTarget.hidden = mode !== "target"
    this.exactFieldsTarget.hidden = mode !== "exact"

    if (mode !== "target" && this.hasTargetInputTarget) {
      this.targetInputTarget.value = ""
    }
    if (mode !== "exact") {
      if (this.hasStartsOnTarget) this.startsOnTarget.value = ""
      if (this.hasEndsOnTarget) this.endsOnTarget.value = ""
    }
  }

  selectedMode() {
    const checked = this.modeTargets.find((input) => input.checked)
    return checked ? checked.value : "unknown"
  }
}
