import { Controller } from "@hotwired/stimulus"

// Sums up a supplier payment in one sentence as the form is filled in,
// matching SupplierMoneyHelper#schedule_line_sentence.
export default class extends Controller {
  static targets = ["output"]
  static values = { currency: String, unit: String, groups: Object, events: Object }

  connect() {
    this.update()
  }

  update() {
    const how = this.howMuch()
    const when = this.whenDue()
    if (!how || !when) {
      this.outputTarget.textContent = "Choose how much and when."
      return
    }
    this.outputTarget.textContent = `${how}, ${when}.`
  }

  howMuch() {
    const kind = this.choice("schedule_line[amount_kind]")
    switch (kind) {
      case "fixed": return this.money("amount")
      case "per_shell": {
        const rate = this.money("rate")
        const group = this.groupsValue[this.field("inventory_group_id")]
        return rate && `${rate} for each ${group ? `${group.label} ${group.noun}` : this.unitValue}`
      }
      case "per_unit_count": {
        const rate = this.money("rate")
        return rate && `${rate} for each one in the count`
      }
      case "percentage_of_cost_line": {
        const percentage = this.field("percentage").trim()
        const select = this.element.querySelector("[name='schedule_line[cost_line_id]']")
        const cost = select && select.selectedOptions[0] ? select.selectedOptions[0].text : ""
        return percentage && cost && `${percentage}% of ${cost}`
      }
      default: return null
    }
  }

  whenDue() {
    const choice = this.choice("schedule_line[when]")
    const date = this.date()
    const unit = this.currentNoun()
    const perUnit = this.choice("schedule_line[amount_kind]") === "per_shell"
    const booked = perUnit ? `a client booking for that ${unit} is confirmed` : this.eventsValue.client_booking_confirmed
    switch (choice) {
      case "date": return date && `due ${date}`
      case "booked": return `due when ${booked}`
      case "booked_or_date":
        if (!date) return null
        return perUnit ? `due when ${booked}, or on ${date} for any ${unit} still unbooked` : `due when ${booked}, or on ${date} at the latest`
      case "after_event": {
        const type = this.field("trigger_type")
        const event = this.eventsValue[type] || "the event is recorded"
        const days = parseInt(this.field("days_after"), 10) || 0
        if (days > 0) return `due ${days} ${days === 1 ? "day" : "days"} after ${event}`
        return type === "service_date" ? "due on the service date" : `due when ${event}`
      }
      default: return null
    }
  }

  currentNoun() {
    const group = this.groupsValue[this.field("inventory_group_id")]
    return group ? group.noun : this.unitValue
  }

  choice(name) {
    const checked = this.element.querySelector(`input[type=radio][name='${name}']:checked`)
    return checked ? checked.value : null
  }

  field(name) {
    const element = this.element.querySelector(`[name='schedule_line[${name}]']`)
    return element ? element.value : ""
  }

  money(name) {
    const amount = Number(this.field(name).replace(/,/g, "").trim())
    if (!this.field(name).trim() || Number.isNaN(amount)) return null
    try {
      return new Intl.NumberFormat("en-US", { style: "currency", currency: this.currencyValue }).format(amount)
    } catch {
      return `${amount} ${this.currencyValue}`
    }
  }

  date() {
    const value = this.field("due_on")
    if (!value) return null
    const [year, month, day] = value.split("-").map(Number)
    const name = new Date(Date.UTC(year, month - 1, day)).toLocaleDateString("en-US", { month: "short", timeZone: "UTC" })
    return `${name} ${day}, ${year}`
  }
}
