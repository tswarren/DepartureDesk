import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["list", "template", "row", "addButton"]
  static values = { nextIndex: Number }

  add(event) {
    event.preventDefault()
    const index = this.nextIndexValue
    const html = this.templateTarget.innerHTML.replaceAll("__INDEX__", String(index))
    this.listTarget.insertAdjacentHTML("beforeend", html)
    this.nextIndexValue = index + 1
    const added = this.rowTargets[this.rowTargets.length - 1]
    added?.querySelector("input, select")?.focus()
  }

  remove(event) {
    event.preventDefault()
    const row = event.currentTarget.closest("[data-price-occupancy-fields-target='row']")
    if (!row || this.rowTargets.length <= 1) return
    row.remove()
  }
}
