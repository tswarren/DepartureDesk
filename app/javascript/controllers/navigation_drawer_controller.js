import { Controller } from "@hotwired/stimulus"

const FOCUSABLE_SELECTOR = [
  "a[href]",
  "button:not([disabled])",
  "textarea:not([disabled])",
  "input:not([disabled]):not([type='hidden'])",
  "select:not([disabled])",
  "[tabindex]:not([tabindex='-1'])"
].join(", ")

export default class extends Controller {
  static targets = [ "drawer", "toggle", "main", "backdrop", "close", "topbar" ]

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
    this.lockBackground()
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
    if (wasOpen && this.hasToggleTarget) this.toggleTarget.focus()
  }

  closeQuietly() {
    if (!this.hasDrawerTarget) return
    this.drawerTarget.classList.remove("is-open")
    if (this.hasToggleTarget) this.toggleTarget.setAttribute("aria-expanded", "false")
    this.unlock()
  }

  keydown(event) {
    if (event.key === "Escape") {
      this.close(event)
      return
    }
    if (event.key !== "Tab") return

    const focusable = this.focusableInDrawer()
    if (focusable.length === 0) {
      event.preventDefault()
      return
    }

    const first = focusable[0]
    const last = focusable[focusable.length - 1]
    const active = document.activeElement

    if (!this.drawerTarget.contains(active)) {
      event.preventDefault()
      first.focus()
      return
    }

    if (event.shiftKey && active === first) {
      event.preventDefault()
      last.focus()
    } else if (!event.shiftKey && active === last) {
      event.preventDefault()
      first.focus()
    }
  }

  lockBackground() {
    if (this.hasMainTarget) this.mainTarget.inert = true
    if (this.hasTopbarTarget) this.topbarTarget.inert = true
  }

  unlock() {
    if (this.hasMainTarget) this.mainTarget.inert = false
    if (this.hasTopbarTarget) this.topbarTarget.inert = false
    if (this.hasBackdropTarget) this.backdropTarget.hidden = true
    document.body.classList.remove("dd-drawer-open")
    document.removeEventListener("keydown", this.onKeydown)
  }

  focusableInDrawer() {
    return Array.from(this.drawerTarget.querySelectorAll(FOCUSABLE_SELECTOR)).filter((element) => {
      if (element.closest("[inert]")) return false
      if (element.getAttribute("aria-hidden") === "true") return false
      return element.getClientRects().length > 0
    })
  }
}
