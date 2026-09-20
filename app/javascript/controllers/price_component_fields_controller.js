import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["list", "template", "row", "addButton"]
  static values = { nextIndex: Number }

  connect() {
    this.update()
  }

  add(event) {
    event.preventDefault()
    const index = this.nextIndexValue
    const html = this.templateTarget.innerHTML.replaceAll("__INDEX__", String(index))
    this.listTarget.insertAdjacentHTML("beforeend", html)
    this.nextIndexValue = index + 1
    this.update()
    const added = this.rowTargets[this.rowTargets.length - 1]
    added?.querySelector("input, select, textarea, button")?.focus()
  }

  remove(event) {
    event.preventDefault()
    const row = event.currentTarget.closest("[data-price-component-fields-target='row']")
    if (!row || this.rowTargets.length <= 1) return
    row.remove()
    this.update()
  }

  update() {
    this.element.querySelectorAll("[data-price-kind]").forEach((group) => {
      const row = group.closest("[data-price-component]")
      const kind = row?.querySelector("[data-price-kind-select]")?.value
      const visible = kind && group.dataset.priceKind.split(" ").includes(kind)
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
