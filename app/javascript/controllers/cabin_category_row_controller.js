import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "inventory", "quantity" ]

  connect() {
    this.toggle()
  }

  toggle() {
    const numeric = this.inventoryTarget.value === "block"
    this.quantityTarget.hidden = !numeric
    this.quantityTarget.querySelectorAll("input").forEach((input) => {
      input.disabled = !numeric
    })
  }
}
