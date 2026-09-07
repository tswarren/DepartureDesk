import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "drawer", "toggle", "main", "backdrop", "close" ]

  connect() {
    this.onKeydown = this.keydown.bind(this)
    this.onNavigate = this.closeQuietly.bind(this)
    document.addEventListener("turbo:before-cache", this.onNavigate)
    document.addEventListener("turbo:load", this.onNavigate)
    this.closeQuietly()
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKeydown)
    document.removeEventListener("turbo:before-cache", this.onNavigate)
    document.removeEventListener("turbo:load", this.onNavigate)
    this.unlock()
  }

  toggle(event) {
    event.preventDefault()
    if (this.drawerTarget.classList.contains("is-open")) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    this.drawerTarget.classList.add("is-open")
    this.toggleTarget.setAttribute("aria-expanded", "true")
    this.mainTarget.inert = true
    if (this.hasBackdropTarget) this.backdropTarget.hidden = false
    document.body.classList.add("dd-drawer-open")
    document.addEventListener("keydown", this.onKeydown)
    const focusTarget = this.hasCloseTarget ? this.closeTarget : this.drawerTarget.querySelector("a")
    focusTarget?.focus()
  }

  close(event) {
    event?.preventDefault()
    const wasOpen = this.drawerTarget.classList.contains("is-open")
    this.closeQuietly()
    if (wasOpen) this.toggleTarget.focus()
  }

  closeQuietly() {
    if (!this.hasDrawerTarget) return
    this.drawerTarget.classList.remove("is-open")
    if (this.hasToggleTarget) this.toggleTarget.setAttribute("aria-expanded", "false")
    this.unlock()
  }

  keydown(event) {
    if (event.key === "Escape") this.close(event)
  }

  unlock() {
    if (this.hasMainTarget) this.mainTarget.inert = false
    if (this.hasBackdropTarget) this.backdropTarget.hidden = true
    document.body.classList.remove("dd-drawer-open")
    document.removeEventListener("keydown", this.onKeydown)
  }
}
