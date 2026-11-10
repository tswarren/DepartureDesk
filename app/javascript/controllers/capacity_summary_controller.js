import { Controller } from "@hotwired/stimulus"
import { longDate } from "helpers/format"

// Sums up a capacity change in one sentence as the form is filled in (UX
// consolidation audit C2): what the supplier holds afterwards, and what is
// left once bookings take theirs. The command still decides.
export default class extends Controller {
  static targets = ["output", "quantity", "shell", "direction", "date"]
  static values = { supply: Number, used: Number, unit: String }

  connect() {
    this.update()
  }

  update() {
    this.outputTarget.textContent = this.sentence() || "Choose what happened and how many."
  }

  sentence() {
    const kind = this.element.querySelector("input[name=kind]:checked")?.value
    const from = this.hasDateTarget && this.dateTarget.value ? `from ${longDate(this.dateTarget.value)}` : "from today"
    const supply = this.supplyValue
    const used = this.usedValue
    const count = kind === "supplier_release" && this.hasShellTarget ? 1 : this.quantity()
    if (!count) return null

    switch (kind) {
      case "increase":
        return `The supplier gives ${count} more ${count === 1 ? this.unitValue : `${this.unitValue}s`} ${from}: ${this.after(supply + count)}`
      case "supplier_release": {
        const what = this.hasShellTarget ? this.shellTarget.selectedOptions[0]?.text : this.units(count)
        const left = supply - count
        if (used > left) {
          return `The supplier takes back ${what} ${from}. That leaves ${this.units(Math.max(left, 0))} while bookings hold ${used}, so ${used - Math.max(left, 0)} short; the bookings affected are flagged.`
        }
        return `The supplier takes back ${what} ${from}: ${this.after(left)}`
      }
      case "correction": {
        const up = this.hasDirectionTarget && this.directionTarget.value === "up"
        if (up) return `The right number is ${count} more ${from}: ${this.after(supply + count)}`
        const free = Math.max(supply - used, 0)
        if (count > free) return `Only ${this.units(free)} no booking holds can go, so this will be refused.`
        return `The right number is ${count} fewer ${from}: ${this.after(supply - count)}`
      }
      default:
        return null
    }
  }

  after(total) {
    return `${this.units(total)} from the supplier, ${Math.max(total - this.usedValue, 0)} left.`
  }

  quantity() {
    const field = this.quantityTargets.find((input) => !input.disabled)
    const value = field ? parseInt(field.value, 10) : NaN
    return Number.isInteger(value) && value > 0 ? value : null
  }

  units(count) {
    return `${count} ${count === 1 ? this.unitValue : `${this.unitValue}s`}`
  }
}
