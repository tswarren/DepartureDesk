import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["organizationFields", "individualFields", "kind"]

  connect() {
    this.update()
  }

  update() {
    const selected = this.kindTargets.find((input) => input.checked)?.value || "organization"
    this.organizationFieldsTarget.hidden = selected !== "organization"
    this.individualFieldsTarget.hidden = selected !== "individual"
  }
}
