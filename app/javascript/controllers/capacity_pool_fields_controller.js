import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["inventoryMode", "quantityGroup", "quantity"]

  connect() {
    this.update()
  }

  update() {
    const numeric = ["block", "allotment"].includes(this.inventoryModeTarget.value)
    this.quantityGroupTarget.hidden = !numeric
    this.quantityTarget.disabled = !numeric
    if (!numeric) this.quantityTarget.value = ""
  }
}
