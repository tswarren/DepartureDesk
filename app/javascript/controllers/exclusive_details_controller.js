import { Controller } from "@hotwired/stimulus"

// Only one <details> editor open at a time within this element (interface contract).
export default class extends Controller {
  connect() {
    this.onToggle = (event) => this.sync(event)
    this.element.addEventListener("toggle", this.onToggle, true)
  }

  disconnect() {
    this.element.removeEventListener("toggle", this.onToggle, true)
  }

  sync(event) {
    const opened = event.target
    if (!opened || opened.tagName !== "DETAILS" || !opened.open) return
    if (!this.element.contains(opened)) return

    this.element.querySelectorAll("details").forEach((details) => {
      if (details !== opened && details.open) details.open = false
    })
  }
}
