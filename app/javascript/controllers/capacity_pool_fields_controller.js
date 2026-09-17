import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "inventoryMode",
    "quantityGroup",
    "quantity",
    "evidenceGroup",
    "overrideToggle",
    "overrideGroup"
  ]
  static values = { inventoryMode: String }

  connect() {
    this.previousInventoryMode = this.currentInventoryMode
    this.renderQuantity()
    this.renderEvidenceChoice()
  }

  updateInventoryMode() {
    const selectedMode = this.currentInventoryMode
    const leavingNumericMode = this.numericMode(this.previousInventoryMode) && !this.numericMode(selectedMode)

    if (leavingNumericMode && this.quantityTarget.value !== "") {
      const confirmed = window.confirm("Changing to a nonnumeric mode will clear the proposed opening quantity. Continue?")
      if (!confirmed) {
        this.inventoryModeTarget.value = this.previousInventoryMode
        this.renderQuantity()
        return
      }
      this.quantityTarget.value = ""
    }

    this.previousInventoryMode = selectedMode
    this.renderQuantity()
  }

  updateOverride() {
    const overrideSelected = this.overrideToggleTarget.checked
    const incompatibleGroup = overrideSelected ? this.evidenceGroupTarget : this.overrideGroupTarget

    if (this.groupHasValues(incompatibleGroup)) {
      const label = overrideSelected ? "Supplier evidence" : "the Administrator override reason"
      const confirmed = window.confirm(`Changing this choice will clear ${label}. Continue?`)
      if (!confirmed) {
        this.overrideToggleTarget.checked = !overrideSelected
        this.renderEvidenceChoice()
        return
      }
      this.clearGroup(incompatibleGroup)
    }

    this.renderEvidenceChoice()
  }

  get currentInventoryMode() {
    return this.hasInventoryModeTarget ? this.inventoryModeTarget.value : this.inventoryModeValue
  }

  numericMode(mode) {
    return ["block", "allotment"].includes(mode)
  }

  renderQuantity() {
    const numeric = this.numericMode(this.currentInventoryMode)
    this.quantityGroupTarget.hidden = !numeric
    this.quantityTarget.disabled = !numeric
  }

  renderEvidenceChoice() {
    if (!this.hasOverrideToggleTarget) return

    const overrideSelected = this.overrideToggleTarget.checked
    this.setGroupVisibility(this.evidenceGroupTarget, !overrideSelected)
    this.setGroupVisibility(this.overrideGroupTarget, overrideSelected)
  }

  setGroupVisibility(group, visible) {
    group.hidden = !visible
    group.querySelectorAll("input, select, textarea").forEach((field) => {
      field.disabled = !visible
    })
  }

  groupHasValues(group) {
    return Array.from(group.querySelectorAll("input, select, textarea")).some((field) => {
      return field.type === "checkbox" ? field.checked : field.value.trim() !== ""
    })
  }

  clearGroup(group) {
    group.querySelectorAll("input, select, textarea").forEach((field) => {
      if (field.type === "checkbox") {
        field.checked = false
      } else {
        field.value = ""
      }
    })
  }
}
