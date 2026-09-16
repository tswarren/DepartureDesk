import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.focus()
    requestAnimationFrame(() => this.element.focus())
  }
}
