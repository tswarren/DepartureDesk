import { Controller } from "@hotwired/stimulus"

// Progressive Reservation response: bulk outcome vs partial; conditional sections.
export default class extends Controller {
  static targets = [
    "mode",
    "bulkOutcome",
    "partialPanel",
    "confirmationPanel",
    "capacityPanel",
    "capacityList",
    "capacityTemplate",
    "scopeOutcome"
  ]

  connect() {
    this.update()
  }

  update() {
    const mode = this.hasModeTarget ? this.modeTarget.value : "all"
    const partial = mode === "partial"
    if (this.hasPartialPanelTarget) {
      this.partialPanelTarget.hidden = !partial
      this.toggleInputs(this.partialPanelTarget, partial)
    }
    if (this.hasBulkOutcomeTarget) {
      this.bulkOutcomeTarget.hidden = partial
      this.toggleInputs(this.bulkOutcomeTarget, !partial)
    }

    const outcome = this.currentOutcome()
    const confirms = outcome === "confirmed" || this.anyPartialConfirmed()
    if (this.hasConfirmationPanelTarget) {
      this.confirmationPanelTarget.hidden = !confirms
      this.toggleInputs(this.confirmationPanelTarget, confirms)
    }
    if (this.hasCapacityPanelTarget) {
      this.capacityPanelTarget.hidden = !confirms
      this.toggleInputs(this.capacityPanelTarget, confirms)
    }

    this.scopeOutcomeTargets.forEach((row) => {
      const kind = row.querySelector("[data-outcome-kind]")?.value || ""
      row.querySelectorAll("[data-outcome-for]").forEach((group) => {
        const allowed = group.dataset.outcomeFor.split(" ")
        const visible = allowed.includes(kind)
        group.hidden = !visible
        this.toggleInputs(group, visible)
      })
    })
  }

  addCapacity(event) {
    event.preventDefault()
    if (!this.hasCapacityTemplateTarget || !this.hasCapacityListTarget) return
    const index = this.capacityListTarget.querySelectorAll("[data-capacity-row]").length
    const html = this.capacityTemplateTarget.innerHTML.replaceAll("__INDEX__", String(index))
    this.capacityListTarget.insertAdjacentHTML("beforeend", html)
  }

  currentOutcome() {
    if (this.hasModeTarget && this.modeTarget.value === "partial") return null
    return this.element.querySelector("[data-bulk-outcome]")?.value || "confirmed"
  }

  anyPartialConfirmed() {
    return this.scopeOutcomeTargets.some((row) => {
      return row.querySelector("[data-outcome-kind]")?.value === "confirmed"
    })
  }

  toggleInputs(container, enabled) {
    container.querySelectorAll("input, select, textarea").forEach((input) => {
      if (input.dataset.keepEnabled === "true") return
      input.disabled = !enabled
    })
  }
}
