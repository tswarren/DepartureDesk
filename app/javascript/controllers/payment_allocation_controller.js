import { Controller } from "@hotwired/stimulus"
import { cents, plainAmount } from "helpers/format"

// Spreads a payment's amount across open installments, oldest first, as it
// is typed (CMN-21). Staff can change any amount afterwards.
export default class extends Controller {
  static targets = ["amount", "row"]

  allocate() {
    let left = cents(this.amountTarget.value)
    this.rowTargets.forEach((row) => {
      const open = cents(row.dataset.open)
      const take = Math.max(Math.min(left, open), 0)
      left -= take
      row.value = take > 0 ? plainAmount(take) : ""
    })
  }
}
