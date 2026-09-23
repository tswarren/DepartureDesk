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

  updateTemplateDefaults() {
    const template = this.hasTemplateTarget ? this.templateTarget.value : ""
    if (template === "initial_deposit") {
      this.amountShapeTarget.value = "quantity_times_rate"
      if (this.hasQuantityBasisTarget) this.quantityBasisTarget.value = "capacity_pool_units"
      if (!this.descriptionTarget.value) this.descriptionTarget.value = "Initial deposit"
    } else if (template === "final_deposit") {
      this.amountShapeTarget.value = "cumulative_target"
      if (this.hasQuantityBasisTarget) this.quantityBasisTarget.value = "capacity_pool_units"
      if (!this.descriptionTarget.value) this.descriptionTarget.value = "Final deposit"
    }
  }

  updateAmount() {
    const shape = this.amountShapeTarget.value
    const basis = this.hasQuantityBasisTarget ? this.quantityBasisTarget.value : ""
    const capacityBased =
      (shape === "quantity_times_rate" && basis === "capacity_pool_units") ||
      shape === "cumulative_target"

    this.setGroup(this.fixedAmountGroupTarget, shape === "fixed_amount")
    this.setGroup(this.rateGroupTarget, shape === "quantity_times_rate" || shape === "cumulative_target")
    this.setGroup(this.quantityBasisGroupTarget, shape === "quantity_times_rate")
    this.setGroup(
      this.explicitQuantityGroupTarget,
      shape === "quantity_times_rate" && basis === "explicit"
    )
    this.setGroup(this.poolGroupTarget, capacityBased)
    this.setGroup(this.contributorGroupTarget, shape === "cumulative_target")
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

  setGroup(node, visible) {
    if (!node) return
    node.hidden = !visible
  }
}
