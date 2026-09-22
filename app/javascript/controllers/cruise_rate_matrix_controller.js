import { Controller } from "@hotwired/stimulus"

// Advisory profile subtotals and narrow-screen column focus for the Cruise
// Supplier rate matrix. Server-compiled values remain authoritative on save.
export default class extends Controller {
  static targets = ["cell", "subtotal", "profileSelect", "profilePosition", "narrowNav", "rowsBody", "customRowTemplate"]

  connect() {
    this.activeProfileIndex = 0
    this.recalculate()
    this.cellTargets.forEach((input) => {
      input.addEventListener("input", () => this.recalculate())
    })
    this.showActiveProfile()
  }

  recalculate() {
    const totals = {}
    this.cellTargets.forEach((input) => {
      const profile = input.dataset.profile
      const role = input.dataset.role
      const raw = (input.value || "").replace(/,/g, "").trim()
      if (raw === "") return
      const amount = Number.parseFloat(raw)
      if (Number.isNaN(amount)) return
      totals[profile] ||= 0
      totals[profile] += role === "supplier_credit" ? -amount : amount
    })
    this.subtotalTargets.forEach((cell) => {
      const profile = cell.dataset.profile
      if (!(profile in totals)) {
        cell.textContent = "—"
        return
      }
      cell.textContent = totals[profile].toLocaleString(undefined, {
        style: "currency",
        currency: "USD",
        minimumFractionDigits: 2
      })
    })
  }

  profileKeys() {
    if (!this.hasProfileSelectTarget) return []
    return Array.from(this.profileSelectTarget.options).map((option) => option.value)
  }

  selectProfile() {
    if (!this.hasProfileSelectTarget) return
    const keys = this.profileKeys()
    const index = keys.indexOf(this.profileSelectTarget.value)
    this.activeProfileIndex = index >= 0 ? index : 0
    this.showActiveProfile()
  }

  previousProfile() {
    const keys = this.profileKeys()
    if (keys.length === 0) return
    this.activeProfileIndex = (this.activeProfileIndex - 1 + keys.length) % keys.length
    this.syncSelect()
    this.showActiveProfile()
  }

  nextProfile() {
    const keys = this.profileKeys()
    if (keys.length === 0) return
    this.activeProfileIndex = (this.activeProfileIndex + 1) % keys.length
    this.syncSelect()
    this.showActiveProfile()
  }

  syncSelect() {
    if (!this.hasProfileSelectTarget) return
    const keys = this.profileKeys()
    this.profileSelectTarget.value = keys[this.activeProfileIndex] || keys[0]
  }

  showActiveProfile() {
    const keys = this.profileKeys()
    if (keys.length === 0) return
    const active = keys[this.activeProfileIndex] || keys[0]
    this.element.querySelectorAll("[data-profile-column]").forEach((node) => {
      const profile = node.getAttribute("data-profile-column")
      node.classList.toggle("is-active-profile", profile === active)
      node.classList.toggle("is-inactive-profile", profile !== active)
    })
    if (this.hasProfilePositionTarget) {
      this.profilePositionTarget.textContent = `${this.activeProfileIndex + 1} of ${keys.length}`
    }
  }

  addComponent() {
    if (!this.hasCustomRowTemplateTarget || !this.hasRowsBodyTarget) return
    const key = `custom_${Date.now().toString(36)}`
    const html = this.customRowTemplateTarget.innerHTML.replaceAll("__KEY__", key)
    const subtotalRow = this.rowsBodyTarget.querySelector("tr:last-child")
    subtotalRow.insertAdjacentHTML("beforebegin", html)
    const inserted = this.rowsBodyTarget.querySelector(`tr[data-row-key="${key}"]`)
    inserted?.querySelectorAll('[data-cruise-rate-matrix-target="cell"]').forEach((input) => {
      input.addEventListener("input", () => this.recalculate())
    })
    this.showActiveProfile()
    this.recalculate()
  }
}
