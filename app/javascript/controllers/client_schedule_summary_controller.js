import { Controller } from "@hotwired/stimulus"
import { longDate, money, parseAmount } from "helpers/format"

// Sums up a client payment schedule line in one sentence as it is filled
// in (UX consolidation audit C2), in the words the client terms page uses
// (PackageHelper#client_schedule_sentence, CMN-09).
export default class extends Controller {
  static targets = ["output"]
  static values = { currency: String, startsOn: String }

  connect() {
    this.update()
  }

  update() {
    const how = this.how()
    const due = this.due()
    this.outputTarget.textContent = how && due
      ? `${how}, ${due}. ${this.checked("counts_as_acceptance") ? "Receiving it counts as the client's acceptance." : "It doesn't count as acceptance."}`
      : "Choose how much and when it is due."
  }

  how() {
    const amount = money(this.value("amount"), this.currencyValue)
    switch (this.value("basis")) {
      case "per_traveler": return amount && `${amount} for each traveler`
      case "per_unit": return amount && `${amount} for each ${this.selectedText("service_category")}`
      case "per_booking": return amount && `${amount} for the booking`
      case "percentage": {
        const percentage = parseAmount(this.value("percentage"))
        return percentage === null ? null : `${percentage}% of the booking total`
      }
      case "balance": return "Whatever remains"
      default: return null
    }
  }

  due() {
    switch (this.value("due_rule")) {
      case "at_confirmation": return "due when the booking is confirmed"
      case "days_before_departure": {
        const days = parseInt(this.value("days_before_departure"), 10)
        if (!Number.isInteger(days) || days < 0) return null
        const date = this.daysBefore(days)
        return `due ${days} ${days === 1 ? "day" : "days"} before departure${date ? `: ${date}` : ""}`
      }
      case "fixed_date": return this.value("due_on") ? `due ${longDate(this.value("due_on"))}` : null
      default: return null
    }
  }

  daysBefore(days) {
    if (!this.startsOnValue) return null
    const [year, month, day] = this.startsOnValue.split("-").map(Number)
    return longDate(new Date(Date.UTC(year, month - 1, day - days)).toISOString().slice(0, 10))
  }

  field(name) {
    return this.element.querySelector(`[name='client_payment_schedule_line[${name}]']:not([type=hidden])`)
  }

  value(name) {
    return this.field(name)?.value ?? ""
  }

  checked(name) {
    return this.field(name)?.checked ?? false
  }

  selectedText(name) {
    return this.field(name)?.selectedOptions[0]?.text ?? "unit"
  }
}
