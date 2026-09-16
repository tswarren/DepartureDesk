import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.focus()
    requestAnimationFrame(() => this.element.focus())
  }

  focusField(event) {
    const href = event.currentTarget.getAttribute("href") || ""
    const id = href.startsWith("#") ? href.slice(1) : ""
    const target = id ? document.getElementById(id) : null
    if (!target) return

    event.preventDefault()
    target.focus()
  }
}
