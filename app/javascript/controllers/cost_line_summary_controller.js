import { Controller } from "@hotwired/stimulus"
import { cents, money, plainAmount } from "helpers/format"

// Sums up a cost line in one sentence as the form is filled in (UX
// consolidation audit C2), in the words the cost table uses
// (SupplierMoneyHelper#cost_line_basis).
export default class extends Controller {
  static targets = ["output"]
  static values = { currency: String }

  connect() {
    this.update()
  }

  update() {
    this.outputTarget.textContent = this.sentence() || "Choose what it covers and enter its amount."
  }

  sentence() {
    const stage = this.value("stage") === "committed" ? "Committed" : "Estimated"
    const covers = this.covers()
    const basis = this.value("basis")
    if (!covers) return null

    if (basis === "percentage") {
      const percentage = this.value("percentage").trim()
      const base = this.selectedText("base_cost_line_id")
      if (!percentage || !base) return null
      return `${stage} cost for ${covers}: ${percentage}% of ${base}, following that line until an amount posts.`
    }
    const rate = this.value("rate")
    if (!money(rate, this.currencyValue)) return null
    if (basis === "fixed") return `${stage} cost of ${money(rate, this.currencyValue)} for ${covers}.`

    const quantity = this.quantity()
    if (!quantity) return null
    const total = money(plainAmount(cents(rate) * quantity), this.currencyValue)
    return `${stage} cost of ${total} for ${covers}: ${money(rate, this.currencyValue)} × ${quantity} ${basis.replace("_", " ")}.`
  }

  covers() {
    switch (this.value("scope")) {
      case "arrangement": return "the whole arrangement"
      case "inventory_group": return this.value("inventory_group_id") ? this.selectedText("inventory_group_id") : null
      case "unit_shells": {
        const shells = this.checkedShells()
        return shells === 0 ? null : `${shells} ${shells === 1 ? "shell" : "shells"}`
      }
      default: return null
    }
  }

  quantity() {
    const typed = parseInt(this.value("quantity"), 10)
    if (Number.isInteger(typed) && typed > 0) return typed
    return this.value("scope") === "unit_shells" ? this.checkedShells() || null : null
  }

  checkedShells() {
    return this.element.querySelectorAll("input[name='cost_line[unit_shell_ids][]']:checked").length
  }

  field(name) {
    return this.element.querySelector(`[name='cost_line[${name}]']`)
  }

  value(name) {
    return this.field(name)?.value ?? ""
  }

  selectedText(name) {
    const select = this.field(name)
    return select && select.value && select.selectedOptions[0] ? select.selectedOptions[0].text : null
  }
}
