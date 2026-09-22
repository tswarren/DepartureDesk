import { Controller } from "@hotwired/stimulus"

// Advisory profile subtotals for the Cruise Supplier rate matrix.
// Server-compiled values remain authoritative on save.
export default class extends Controller {
  static targets = ["cell", "subtotal"]

  connect() {
    this.recalculate()
    this.cellTargets.forEach((input) => {
      input.addEventListener("input", () => this.recalculate())
    })
  }

  recalculate() {
    const totals = {}
    this.cellTargets.forEach((input) => {
      const profile = input.dataset.profile
      const role = input.dataset.role
      const raw = (input.value || "").replace(/,/g, "").trim()
      if (raw === "") return
      const amount = Number.parseFloat(raw)
      if (Number.isNaN(amount)) return
      totals[profile] ||= 0
      totals[profile] += role === "supplier_credit" ? -amount : amount
    })
    this.subtotalTargets.forEach((cell) => {
      const profile = cell.dataset.profile
      if (!(profile in totals)) {
        cell.textContent = "—"
        return
      }
      cell.textContent = totals[profile].toLocaleString(undefined, {
        style: "currency",
        currency: "USD",
        minimumFractionDigits: 2
      })
    })
  }
}
