import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["pattern", "advanced", "zero"]

  connect() {
    this.update()
  }

  update() {
    const mode = this.element.querySelector("[name='price[mode]']")?.value || "calculated"
    const advanced = this.hasAdvancedTarget && !this.advancedTarget.hidden
    if (this.hasPatternTarget) {
      this.toggleInputs(this.patternTarget, mode === "calculated")
      this.patternTarget.hidden = mode !== "calculated"
    }
    if (this.hasZeroTarget) {
      this.zeroTarget.hidden = mode !== "zero_price"
      this.toggleInputs(this.zeroTarget, mode === "zero_price")
    }
    this.element.querySelectorAll("[data-price-kind]").forEach((group) => {
      const row = group.closest("[data-price-component]")
      const kind = row?.querySelector("[data-price-kind-select]")?.value
      const visible = mode === "calculated" && kind && group.dataset.priceKind.split(" ").includes(kind)
      group.hidden = !visible
      this.toggleInputs(group, visible)
    })
  }

  toggleInputs(container, enabled) {
    container.querySelectorAll("input, select, textarea").forEach((input) => {
      if (input.dataset.keepEnabled === "true") return
      input.disabled = !enabled
    })
  }
}
