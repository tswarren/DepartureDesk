import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["fresh", "reuse", "other", "kind"]

  connect() {
    this.toggle()
  }

  toggle() {
    const choice = this.element.querySelector('input[name="proof_choice"]:checked')
    const recording = !choice || choice.value === "new"
    if (this.hasFreshTarget) {
      this.freshTarget.hidden = !recording
      this.setEnabled(this.freshTarget, recording)
    }
    if (this.hasReuseTarget) {
      this.reuseTarget.hidden = recording
      this.setEnabled(this.reuseTarget, !recording)
    }
    if (this.hasOtherTarget && this.hasKindTarget) {
      const other = recording && this.kindTarget.value === "other"
      this.otherTarget.hidden = !other
      this.setEnabled(this.otherTarget, other)
    }
  }

  setEnabled(container, enabled) {
    container.querySelectorAll("input, select, textarea").forEach((field) => {
      field.disabled = !enabled
    })
  }
}
