import { Controller } from "@hotwired/stimulus"

// Focus a summary or editor target when the URL hash matches its id.
export default class extends Controller {
  connect() {
    if (!location.hash) return
    if (`#${this.element.id}` !== location.hash) return

    this.element.focus({ preventScroll: false })
    requestAnimationFrame(() => this.element.focus({ preventScroll: false }))
  }
}
