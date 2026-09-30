import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "inventory", "quantity", "dash" ]

  connect() {
    this.toggle()
  }

  toggle() {
    const numeric = this.inventoryTarget.value === "block"
    this.quantityTarget.hidden = !numeric
    this.quantityTarget.disabled = !numeric
    this.dashTarget.hidden = numeric
  }
}
