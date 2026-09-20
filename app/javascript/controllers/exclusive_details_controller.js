import { Controller } from "@hotwired/stimulus"

// Only one <details> editor open at a time within this element (interface contract).
export default class extends Controller {
  sync(event) {
    const opened = event.target
    if (!(opened instanceof HTMLDetailsElement) || !opened.open) return
    if (!this.element.contains(opened)) return

    this.element.querySelectorAll("details").forEach((details) => {
      if (details !== opened && details.open) details.open = false
    })
  }
}
