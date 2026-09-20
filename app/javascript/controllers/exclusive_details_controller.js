import { Controller } from "@hotwired/stimulus"

// Progressive enhancement for exclusive <details name="..."> groups.
// Modern browsers enforce exclusivity natively via the name attribute.
// toggle does not bubble, so the polyfill listens on each details element.
export default class extends Controller {
  static values = { group: String }

  connect() {
    this.onToggle = (event) => this.sync(event)
    this.panels().forEach((details) => {
      details.addEventListener("toggle", this.onToggle)
    })
  }

  disconnect() {
    this.panels().forEach((details) => {
      details.removeEventListener("toggle", this.onToggle)
    })
  }

  panels() {
    const name = this.groupValue
    if (!name) return Array.from(this.element.querySelectorAll("details"))
    return Array.from(this.element.querySelectorAll("details")).filter(
      (details) => details.getAttribute("name") === name
    )
  }

  sync(event) {
    const opened = event.target
    if (!opened || opened.tagName !== "DETAILS") return

    const justOpened = event.newState ? event.newState === "open" : opened.open
    if (!justOpened) return

    this.panels().forEach((details) => {
      if (details !== opened && details.open) details.open = false
    })
  }
}
