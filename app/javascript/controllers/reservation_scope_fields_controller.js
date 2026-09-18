import { Controller } from "@hotwired/stimulus"

// Progressive Reservation scope rows: one default row, add/remove, target-kind gating.
export default class extends Controller {
  static targets = ["list", "template", "row", "addButton"]
  static values = { nextIndex: Number }

  connect() {
    this.updateRows()
  }

  add(event) {
    event.preventDefault()
    const index = this.nextIndexValue
    const html = this.templateTarget.innerHTML.replaceAll("__INDEX__", String(index))
    this.listTarget.insertAdjacentHTML("beforeend", html)
    this.nextIndexValue = index + 1
    this.updateRows()
    const rows = this.rowTargets
    const added = rows[rows.length - 1]
    const focusable = added?.querySelector("select, input, textarea, button")
    focusable?.focus()
  }

  remove(event) {
    event.preventDefault()
    const row = event.currentTarget.closest("[data-reservation-scope-fields-target='row']")
    if (!row) return
    if (this.rowTargets.length <= 1) return
    row.remove()
    this.updateRows()
  }

  update(event) {
    const row = event.currentTarget.closest("[data-reservation-scope-fields-target='row']")
    if (row) this.updateRow(row)
  }

  updateRows() {
    this.rowTargets.forEach((row) => this.updateRow(row))
    if (this.hasAddButtonTarget) {
      this.addButtonTarget.hidden = this.rowTargets.length >= 20
    }
  }

  updateRow(row) {
    const kindSelect = row.querySelector("[data-scope-kind]")
    const kind = kindSelect?.value || ""
    row.querySelectorAll("[data-scope-for]").forEach((group) => {
      const allowed = group.dataset.scopeFor.split(" ")
      const visible = kind !== "" && allowed.includes(kind)
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
