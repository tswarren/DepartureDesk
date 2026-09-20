import { Controller } from "@hotwired/stimulus"

// Progressive Reservation response: bulk outcome vs partial; conditional sections.
// Confirmation and capacity panels open only when at least one *included, active*
// scope has effective outcome confirmed (not merely a default on an excluded row).
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
      if (!partial) {
        this.toggleInputs(this.partialPanelTarget, false)
      } else {
        this.partialScopeRows().forEach((row) => {
          const included = this.scopeIncluded(row)
          row.querySelectorAll("input, select, textarea").forEach((input) => {
            if (input.matches("input[type='checkbox'][name='scope_ids[]']")) {
              input.disabled = false
              return
            }
            input.disabled = !included
          })
        })
      }
    }
    if (this.hasBulkOutcomeTarget) {
      this.bulkOutcomeTarget.hidden = partial
      this.toggleInputs(this.bulkOutcomeTarget, !partial)
    }

    const confirms = this.hasConfirmedCoverage()
    if (this.hasConfirmationPanelTarget) {
      this.confirmationPanelTarget.hidden = !confirms
      this.toggleInputs(this.confirmationPanelTarget, confirms)
    }
    if (this.hasCapacityPanelTarget) {
      this.capacityPanelTarget.hidden = !confirms
      this.toggleInputs(this.capacityPanelTarget, confirms)
    }

    this.activeScopeRows().forEach((row) => {
      const kind = row.querySelector("[data-outcome-kind]")?.value || ""
      row.querySelectorAll("[data-outcome-for]").forEach((group) => {
        const allowed = group.dataset.outcomeFor.split(" ")
        const visible = allowed.includes(kind)
        group.hidden = !visible
        this.toggleInputs(group, visible && this.scopeActiveForOutcome(row))
      })
    })
  }

  addCapacity(event) {
    event.preventDefault()
    if (!this.hasCapacityTemplateTarget || !this.hasCapacityListTarget) return
    const index = this.capacityListTarget.querySelectorAll("[data-capacity-row]").length
    const html = this.capacityTemplateTarget.innerHTML.replaceAll("__INDEX__", String(index))
    this.capacityListTarget.insertAdjacentHTML("beforeend", html)
    const rows = this.capacityRows()
    const newRow = rows[rows.length - 1]
    this.focusCapacityRow(newRow)
  }

  removeCapacity(event) {
    event.preventDefault()
    if (!this.hasCapacityListTarget) return
    const row = event.currentTarget.closest("[data-capacity-row]")
    if (!row) return

    const rows = this.capacityRows()
    const index = rows.indexOf(row)
    if (rows.length <= 1) {
      this.clearCapacityRow(row)
      this.focusCapacityRow(row)
      return
    }

    row.remove()
    this.reindexCapacityRows()
    const remaining = this.capacityRows()
    const focusIndex = Math.min(index, remaining.length - 1)
    this.focusCapacityRow(remaining[focusIndex])
  }

  capacityRows() {
    if (!this.hasCapacityListTarget) return []
    return Array.from(this.capacityListTarget.querySelectorAll("[data-capacity-row]"))
  }

  focusCapacityRow(row) {
    if (!row) return
    const focusable = row.querySelector("select, input:not([type='hidden']), button")
    focusable?.focus()
  }

  clearCapacityRow(row) {
    row.querySelectorAll("select").forEach((select) => {
      select.selectedIndex = 0
    })
    row.querySelectorAll("input:not([type='hidden'])").forEach((input) => {
      input.value = ""
    })
  }

  reindexCapacityRows() {
    this.capacityRows().forEach((row, index) => {
      row.querySelectorAll("label, select, input, button").forEach((element) => {
        if (element.name) {
          element.name = element.name.replace(
            /capacity_consequences\[\d+]/,
            `capacity_consequences[${index}]`
          )
        }
        if (element.id) {
          element.id = element.id.replace(
            /capacity_consequences_\d+_/,
            `capacity_consequences_${index}_`
          )
        }
        if (element.htmlFor) {
          element.htmlFor = element.htmlFor.replace(
            /capacity_consequences_\d+_/,
            `capacity_consequences_${index}_`
          )
        }
      })
    })
  }

  hasConfirmedCoverage() {
    const mode = this.hasModeTarget ? this.modeTarget.value : "all"
    if (mode === "partial") {
      return this.anyIncludedPartialConfirmed()
    }
    return this.currentOutcome() === "confirmed"
  }

  currentOutcome() {
    if (this.hasModeTarget && this.modeTarget.value === "partial") return null
    return this.element.querySelector("[data-bulk-outcome]")?.value || "confirmed"
  }

  anyIncludedPartialConfirmed() {
    return this.partialScopeRows().some((row) => {
      if (!this.scopeIncluded(row)) return false
      return row.querySelector("[data-outcome-kind]")?.value === "confirmed"
    })
  }

  partialScopeRows() {
    if (!this.hasPartialPanelTarget) return []
    return Array.from(
      this.partialPanelTarget.querySelectorAll("[data-reservation-response-fields-target='scopeOutcome']")
    )
  }

  activeScopeRows() {
    const mode = this.hasModeTarget ? this.modeTarget.value : "all"
    if (mode === "partial") {
      return this.partialScopeRows().filter((row) => this.scopeIncluded(row))
    }
    if (!this.hasBulkOutcomeTarget) return this.scopeOutcomeTargets
    return Array.from(
      this.bulkOutcomeTarget.querySelectorAll("[data-reservation-response-fields-target='scopeOutcome']")
    )
  }

  scopeIncluded(row) {
    const checkbox = row.querySelector("input[type='checkbox'][name='scope_ids[]']")
    if (!checkbox) return true
    return checkbox.checked
  }

  scopeActiveForOutcome(row) {
    const mode = this.hasModeTarget ? this.modeTarget.value : "all"
    if (mode !== "partial") return true
    return this.scopeIncluded(row)
  }

  toggleInputs(container, enabled) {
    container.querySelectorAll("input, select, textarea").forEach((input) => {
      if (input.dataset.keepEnabled === "true") return
      input.disabled = !enabled
    })
  }
}
