import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["list", "row"]

  moveUp(event) {
    this.move(event.currentTarget.closest("li"), -1)
  }

  moveDown(event) {
    this.move(event.currentTarget.closest("li"), 1)
  }

  move(row, delta) {
    if (!row) return
    const rows = Array.from(this.rowTargets)
    const index = rows.indexOf(row)
    const target = index + delta
    if (target < 0 || target >= rows.length) return

    if (delta < 0) {
      this.listTarget.insertBefore(row, rows[target])
    } else {
      const after = rows[target].nextSibling
      this.listTarget.insertBefore(row, after)
    }
  }
}
