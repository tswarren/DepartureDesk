import { Controller } from "@hotwired/stimulus"

// Asks before leaving a form with unsaved changes (first-slice UI acceptance).
export default class extends Controller {
  static values = { message: { type: String, default: "You have unsaved changes. Leave this page?" } }

  connect() {
    this.dirty = false
    this.markDirty = () => { this.dirty = true }
    this.clear = () => { this.dirty = false }
    this.beforeUnload = (event) => {
      if (!this.dirty) return
      event.preventDefault()
      event.returnValue = ""
    }
    this.beforeVisit = (event) => {
      if (this.dirty && !window.confirm(this.messageValue)) event.preventDefault()
    }

    this.element.addEventListener("input", this.markDirty)
    this.element.addEventListener("change", this.markDirty)
    this.element.addEventListener("submit", this.clear)
    window.addEventListener("beforeunload", this.beforeUnload)
    document.addEventListener("turbo:before-visit", this.beforeVisit)
  }

  disconnect() {
    this.element.removeEventListener("input", this.markDirty)
    this.element.removeEventListener("change", this.markDirty)
    this.element.removeEventListener("submit", this.clear)
    window.removeEventListener("beforeunload", this.beforeUnload)
    document.removeEventListener("turbo:before-visit", this.beforeVisit)
  }
}
