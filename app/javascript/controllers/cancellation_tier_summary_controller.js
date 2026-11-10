import { Controller } from "@hotwired/stimulus"
import { longDate, money, parseAmount } from "helpers/format"

// Sums up a cancellation tier in one sentence as it is filled in (UX
// consolidation audit C2), in the words the terms pages use
// (PackageHelper#tier_charge, BKG-31). The tier runs until the next one
// closer to departure.
export default class extends Controller {
  static targets = ["output"]
  static values = { currency: String, startsOn: String }

  connect() {
    this.update()
  }

  update() {
    const days = parseInt(this.value("min_days_before_departure"), 10)
    const charge = this.charge()
    if (!Number.isInteger(days) || days < 0 || !charge) {
      this.outputTarget.textContent = "Enter the days before departure and what a cancellation then costs."
      return
    }
    const date = this.daysBefore(days)
    const when = days === 0
      ? "Cancelling in the final tier, up to departure,"
      : `Cancelling ${days} ${days === 1 ? "day" : "days"} or more before departure${date ? ` (by ${date})` : ""}`
    this.outputTarget.textContent = `${when} costs ${charge}${days === 0 ? "." : ", until the next tier closer to departure."}`
  }

  charge() {
    const amount = money(this.value("amount"), this.currencyValue)
    switch (this.value("charge_kind")) {
      case "percentage": {
        const percentage = parseAmount(this.value("percentage"))
        return percentage === null ? null : `${percentage}% of the service's charge`
      }
      case "fixed_per_traveler": return amount && `${amount} for each traveler`
      case "fixed_per_unit": return amount && `${amount} for each ${this.field("service_category")?.selectedOptions[0]?.text ?? "unit"}`
      default: return null
    }
  }

  daysBefore(days) {
    if (!this.startsOnValue) return null
    const [year, month, day] = this.startsOnValue.split("-").map(Number)
    return longDate(new Date(Date.UTC(year, month - 1, day - days)).toISOString().slice(0, 10))
  }

  field(name) {
    return this.element.querySelector(`[name$='[${name}]']:not([type=hidden])`)
  }

  value(name) {
    return this.field(name)?.value ?? ""
  }
}
