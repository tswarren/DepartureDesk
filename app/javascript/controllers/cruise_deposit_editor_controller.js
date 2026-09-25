import { Controller } from "@hotwired/stimulus"

// Conditional Cruise deposit editor with write-free amount preview.
export default class extends Controller {
  static targets = [
    "template",
    "description",
    "descriptionGroup",
    "amountShape",
    "fixedAmountGroup",
    "fixedAmount",
    "rateGroup",
    "rateAmount",
    "quantityBasisGroup",
    "quantityBasis",
    "explicitQuantityGroup",
    "explicitQuantity",
    "coverageScopeGroup",
    "coverageScope",
    "resourceGroup",
    "resourceCheckbox",
    "poolGroup",
    "poolCheckbox",
    "contributorGroup",
    "contributorCheckbox",
    "ruleShape",
    "fixedDateGroup",
    "fixedDatetimeGroup",
    "offsetDaysGroup",
    "offsetHoursGroup",
    "compositeGroup",
    "arm1RuleShape",
    "arm1FixedDateGroup",
    "arm1OffsetDaysGroup",
    "arm2RuleShape",
    "arm2FixedDateGroup",
    "arm2OffsetDaysGroup",
    "previewOutput",
    "previewLabel",
    "previewPending"
  ]

  static values = {
    previewUrl: String,
    versionLockVersion: Number
  }

  connect() {
    this.previewSequence = 0
    this.lastTemplate = null
    this.nameStaffAuthored = this.initNameStaffAuthored()
    this.update()
    this.schedulePreview()
  }

  update() {
    this.updateTemplateDefaults()
    this.updateAmount()
    this.updateTiming()
  }

  schedulePreview() {
    this.update()
    clearTimeout(this.previewTimer)
    this.previewTimer = setTimeout(() => this.requestPreview(), 250)
  }

  markNameStaffAuthored() {
    this.nameStaffAuthored = true
    if (this.hasDescriptionTarget) this.descriptionTarget.dataset.staffAuthored = "true"
  }

  initNameStaffAuthored() {
    if (!this.hasDescriptionTarget) return false
    if (this.descriptionTarget.dataset.staffAuthored === "true") return true

    return this.descriptionIsStaffAuthoredFor(
      this.hasTemplateTarget ? this.templateTarget.value : ""
    )
  }

  generatedNameFor(template) {
    if (template === "initial_deposit") return "Initial deposit"
    if (template === "final_deposit") return "Final deposit"
    return null
  }

  descriptionIsStaffAuthoredFor(template) {
    const value = (this.descriptionTarget.value || "").trim()
    if (!value) return false

    const generated = this.generatedNameFor(template)
    if (generated === null) return true

    return value !== generated
  }

  updateTemplateDefaults() {
    const template = this.hasTemplateTarget ? this.templateTarget.value : ""
    if (template === this.lastTemplate) return

    const previous = this.lastTemplate
    this.lastTemplate = template
    this.captureStaffAuthoredName(previous)

    if (template === "initial_deposit") {
      this.amountShapeTarget.value = "quantity_times_rate"
      if (this.hasQuantityBasisTarget) this.quantityBasisTarget.value = "capacity_pool_units"
      this.applyGeneratedName("Initial deposit")
    } else if (template === "final_deposit") {
      this.amountShapeTarget.value = "cumulative_target"
      if (this.hasQuantityBasisTarget) this.quantityBasisTarget.value = "capacity_pool_units"
      this.applyGeneratedName("Final deposit")
    } else {
      this.clearGeneratedName(previous)
    }
  }

  captureStaffAuthoredName(previousTemplate) {
    if (this.nameStaffAuthored || !this.hasDescriptionTarget) return

    const current = (this.descriptionTarget.value || "").trim()
    if (!current) return

    const previousGenerated = previousTemplate == null ? null : this.generatedNameFor(previousTemplate)
    const nextGenerated = this.generatedNameFor(this.hasTemplateTarget ? this.templateTarget.value : "")
    if (current === previousGenerated || current === nextGenerated) return

    this.nameStaffAuthored = true
    this.descriptionTarget.dataset.staffAuthored = "true"
  }

  applyGeneratedName(generated) {
    if (!this.hasDescriptionTarget || this.nameStaffAuthored) return

    this.descriptionTarget.value = generated
  }

  clearGeneratedName(previousTemplate) {
    if (!this.hasDescriptionTarget || this.nameStaffAuthored) return

    const current = (this.descriptionTarget.value || "").trim()
    const previousGenerated = previousTemplate == null ? null : this.generatedNameFor(previousTemplate)
    if (current && current !== previousGenerated) {
      this.nameStaffAuthored = true
      this.descriptionTarget.dataset.staffAuthored = "true"
      return
    }

    this.descriptionTarget.value = ""
  }

  updateAmount() {
    const shape = this.amountShapeTarget.value
    const basis = this.hasQuantityBasisTarget ? this.quantityBasisTarget.value : ""
    const capacityBased =
      (shape === "quantity_times_rate" && basis === "capacity_pool_units") ||
      shape === "cumulative_target"
    const coverageScope = this.hasCoverageScopeTarget ? this.coverageScopeTarget.value : "arrangement"
    const showIndependentCoverage = shape !== "" && !capacityBased

    this.setGroup(this.fixedAmountGroupTarget, shape === "fixed_amount")
    this.setGroup(this.rateGroupTarget, shape === "quantity_times_rate" || shape === "cumulative_target")
    this.setGroup(this.quantityBasisGroupTarget, shape === "quantity_times_rate")
    this.setGroup(
      this.explicitQuantityGroupTarget,
      shape === "quantity_times_rate" && basis === "explicit"
    )
    this.setGroup(this.coverageScopeGroupTarget, showIndependentCoverage)
    this.setGroup(
      this.resourceGroupTarget,
      showIndependentCoverage && coverageScope === "resource"
    )
    this.setGroup(
      this.poolGroupTarget,
      capacityBased || (showIndependentCoverage && coverageScope === "capacity_pool")
    )
    this.setGroup(this.contributorGroupTarget, shape === "cumulative_target", { clearCheckboxes: true })
  }

  updateTiming() {
    const shape = this.ruleShapeTarget.value
    const composite = shape === "earlier_of"

    this.setGroup(this.fixedDateGroupTarget, shape === "fixed_date")
    this.setGroup(this.fixedDatetimeGroupTarget, shape === "fixed_local_datetime")
    this.setGroup(
      this.offsetDaysGroupTarget,
      shape === "days_before_departure" || shape === "days_after_departure"
    )
    this.setGroup(
      this.offsetHoursGroupTarget,
      shape === "hours_before_departure" || shape === "hours_after_departure"
    )
    this.setGroup(this.compositeGroupTarget, composite)

    if (composite) {
      this.updateArm("arm1")
      this.updateArm("arm2")
    }
  }

  updateArm(prefix) {
    const shapeTarget = this[`${prefix}RuleShapeTarget`]
    if (!shapeTarget) return
    const shape = shapeTarget.value
    this.setGroup(this[`${prefix}FixedDateGroupTarget`], shape === "fixed_date")
    this.setGroup(
      this[`${prefix}OffsetDaysGroupTarget`],
      shape === "days_before_departure" || shape === "days_after_departure"
    )
  }

  async requestPreview() {
    if (!this.previewUrlValue) return

    const sequence = ++this.previewSequence
    const form = this.element.querySelector("form")
    if (!form) return

    const body = new FormData(form)
    body.set("version_lock_version", String(this.versionLockVersionValue))
    body.set("request_token", String(sequence))

    try {
      const response = await fetch(this.previewUrlValue, {
        method: "POST",
        headers: {
          Accept: "application/json",
          "X-CSRF-Token": this.csrfToken()
        },
        body,
        credentials: "same-origin"
      })
      const payload = await response.json()
      if (sequence !== this.previewSequence) return
      if (Number(payload.request_token) !== sequence) return

      this.renderPreview(payload)
    } catch (_error) {
      if (sequence !== this.previewSequence) return
      this.previewPendingTarget.hidden = false
      this.previewPendingTarget.textContent = "Amount preview unavailable. Values were left unchanged."
    }
  }

  renderPreview(payload) {
    if (payload.stale) {
      this.previewOutputTarget.textContent = "Preview is stale. Refresh the page."
      this.previewPendingTarget.hidden = false
      this.previewPendingTarget.textContent = (payload.pending_reasons || []).join(" ")
      this.previewLabelTarget.hidden = true
      return
    }

    if (payload.status === "ready" && payload.amount_display) {
      this.previewOutputTarget.textContent = payload.amount_display
      if (payload.quantity_label) {
        this.previewLabelTarget.hidden = false
        this.previewLabelTarget.textContent = payload.quantity_label
      } else {
        this.previewLabelTarget.hidden = true
      }
      this.previewPendingTarget.hidden = true
      this.previewPendingTarget.textContent = ""
      return
    }

    this.previewOutputTarget.textContent = "Preview pending"
    this.previewLabelTarget.hidden = true
    this.previewPendingTarget.hidden = false
    this.previewPendingTarget.textContent = (payload.pending_reasons || [ "Amount cannot be calculated yet." ]).join(" ")
  }

  csrfToken() {
    const node = document.querySelector("meta[name='csrf-token']")
    return node ? node.getAttribute("content") : ""
  }

  setGroup(node, visible, { clearCheckboxes = false } = {}) {
    if (!node) return
    node.hidden = !visible
    node.querySelectorAll("input, select, textarea").forEach((field) => {
      field.disabled = !visible
      if (!visible && clearCheckboxes && field.type === "checkbox") {
        field.checked = false
      }
    })
  }
}
