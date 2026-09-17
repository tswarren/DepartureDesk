import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["mode", "kind", "calculated", "zeroCost"]

  connect() {
    this.update()
  }

  update() {
    const calculated = this.modeTarget.value === "calculated"
    this.calculatedTarget.hidden = !calculated
    this.zeroCostTarget.hidden = calculated
    this.toggleInputs(this.calculatedTarget, calculated)
    this.toggleInputs(this.zeroCostTarget, !calculated)

    const kind = this.kindTarget.value
    this.element.querySelectorAll("[data-cost-kind]").forEach((group) => {
      const visible = calculated && group.dataset.costKind.split(" ").includes(kind)
      group.hidden = !visible
      this.toggleInputs(group, visible)
    })
  }

  toggleInputs(container, enabled) {
    container.querySelectorAll("input, select, textarea").forEach((input) => {
      input.disabled = !enabled
    })
  }
}
