import { Controller } from "@hotwired/stimulus"

// Spreads a payment's amount across open installments, oldest first, as it
// is typed (CMN-21). Staff can change any amount afterwards.
export default class extends Controller {
  static targets = ["amount", "row"]

  allocate() {
    let left = this.cents(this.amountTarget.value)
    this.rowTargets.forEach((row) => {
      const open = this.cents(row.dataset.open)
      const take = Math.max(Math.min(left, open), 0)
      left -= take
      row.value = take > 0 ? (take / 100).toFixed(2) : ""
    })
  }

  cents(value) {
    const amount = Number(String(value || "").replace(/,/g, "").trim())
    return Number.isFinite(amount) ? Math.round(amount * 100) : 0
  }
}
