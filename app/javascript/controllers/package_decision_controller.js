import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["choice", "packageFields"]

  connect() {
    this.update()
  }

  update() {
    const selected = this.choiceTargets.find((input) => input.checked)
    const yes = !selected || selected.value === "yes"
    if (this.hasPackageFieldsTarget) this.packageFieldsTarget.hidden = !yes
  }
}
