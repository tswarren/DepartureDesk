import { Controller } from "@hotwired/stimulus"

// Conditional Cruise deadline editor: template, timing, coverage, and live previews.
export default class extends Controller {
  static targets = [
    "template",
    "labelGroup",
    "labelInput",
    "finalPaymentLabel",
    "kindGroup",
    "kindSelect",
    "actionExplanation",
    "ruleShape",
    "fixedDateGroup",
    "fixedDatetimeGroup",
    "offsetDaysGroup",
    "offsetHoursGroup",
    "compositeGroup",
    "arm1RuleShape",
    "arm1FixedDateGroup",
    "arm1FixedDatetimeGroup",
    "arm1OffsetDaysGroup",
    "arm1OffsetHoursGroup",
    "arm2RuleShape",
    "arm2FixedDateGroup",
    "arm2FixedDatetimeGroup",
    "arm2OffsetDaysGroup",
    "arm2OffsetHoursGroup",
    "coverageScope",
    "resourceGroup",
    "poolGroup",
    "resourceSelect",
    "poolSelect",
    "timingPreview",
    "coveragePreview",
    "consequencePreview",
    "timeZone"
  ]

  static values = {
    finalPaymentLabel: { type: String, default: "Final payment" },
    explanations: Object
  }

  connect() {
    this.update()
  }

  update() {
    this.updateTemplate()
    this.updateTiming()
    this.updateCoverage()
    this.updatePreviews()
  }

  updateTemplate() {
    const template = this.templateTarget.value
    const kindFixed = template === "option_or_release" || template === "rooming_list"
    const labelEditable = template === "other"
    const showFinalPaymentLabel = template === "final_payment"
    const showOtherLabel = labelEditable

    this.setGroup(this.labelGroupTarget, showOtherLabel || showFinalPaymentLabel)
    if (this.hasLabelInputTarget) {
      this.labelInputTarget.hidden = !showOtherLabel
      this.labelInputTarget.disabled = !showOtherLabel
      if (showFinalPaymentLabel) this.labelInputTarget.value = ""
    }
    if (this.hasFinalPaymentLabelTarget) {
      this.finalPaymentLabelTarget.hidden = !showFinalPaymentLabel
    }

    this.setGroup(this.kindGroupTarget, !kindFixed && template !== "")
    if (kindFixed) {
      if (template === "option_or_release") this.kindSelectTarget.value = "actionable"
      if (template === "rooming_list") this.kindSelectTarget.value = "informational"
    }
    this.kindSelectTarget.disabled = kindFixed || template === ""

    const explanation = this.explanationsValue[template] || "Choose a template to see activation consequences."
    if (this.hasActionExplanationTarget) this.actionExplanationTarget.textContent = explanation
  }

  updateTiming() {
    const shape = this.ruleShapeTarget.value
    const composite = shape === "earlier_of" || shape === "later_of"

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
    } else {
      this.disableArm("arm1")
      this.disableArm("arm2")
    }
  }

  updateArm(prefix) {
    const shapeSelect = this[`${prefix}RuleShapeTarget`]
    const shape = shapeSelect?.value || ""
    this.setGroup(this[`${prefix}FixedDateGroupTarget`], shape === "fixed_date")
    this.setGroup(this[`${prefix}FixedDatetimeGroupTarget`], shape === "fixed_local_datetime")
    this.setGroup(
      this[`${prefix}OffsetDaysGroupTarget`],
      shape === "days_before_departure" || shape === "days_after_departure"
    )
    this.setGroup(
      this[`${prefix}OffsetHoursGroupTarget`],
      shape === "hours_before_departure" || shape === "hours_after_departure"
    )
    shapeSelect.disabled = false
  }

  disableArm(prefix) {
    const shapeSelect = this[`${prefix}RuleShapeTarget`]
    if (shapeSelect) shapeSelect.disabled = true
    this.setGroup(this[`${prefix}FixedDateGroupTarget`], false)
    this.setGroup(this[`${prefix}FixedDatetimeGroupTarget`], false)
    this.setGroup(this[`${prefix}OffsetDaysGroupTarget`], false)
    this.setGroup(this[`${prefix}OffsetHoursGroupTarget`], false)
  }

  updateCoverage() {
    const scope = this.coverageScopeTarget.value
    this.setGroup(this.resourceGroupTarget, scope === "resource")
    this.setGroup(this.poolGroupTarget, scope === "capacity_pool")
  }

  updatePreviews() {
    if (this.hasTimingPreviewTarget) {
      this.timingPreviewTarget.textContent = this.timingSentence()
    }
    if (this.hasCoveragePreviewTarget) {
      this.coveragePreviewTarget.textContent = this.coverageSentence()
    }
    if (this.hasConsequencePreviewTarget) {
      const template = this.templateTarget.value
      const kind = this.kindSelectTarget.disabled
        ? (template === "rooming_list" ? "informational" : "actionable")
        : this.kindSelectTarget.value
      let text = this.explanationsValue[template] || "Choose a template to see activation consequences."
      if (template === "final_payment" || template === "other") {
        text = kind === "actionable"
          ? "On activation, opens one actionable Supplier commitment for the required action or evidence."
          : "On activation, records an informational requirement. No Supplier commitment opens."
      }
      this.consequencePreviewTarget.textContent = text
    }
  }

  timingSentence() {
    const shape = this.ruleShapeTarget.value
    const zone = this.hasTimeZoneTarget ? this.timeZoneTarget.value : ""
    if (!shape) return "Choose timing to preview the due sentence."

    switch (shape) {
      case "fixed_date": {
        const date = this.groupValue(this.fixedDateGroupTarget, "input")
        return date ? `Due on ${date} (${zone})` : "Enter a fixed date."
      }
      case "fixed_local_datetime": {
        const datetime = this.groupValue(this.fixedDatetimeGroupTarget, "input")
        return datetime ? `Due at ${datetime} (${zone})` : "Enter a fixed local date and time."
      }
      case "days_before_departure":
      case "days_after_departure": {
        const days = this.groupValue(this.offsetDaysGroupTarget, "input")
        if (days === "") return "Enter a day offset."
        const direction = shape === "days_before_departure" ? "before" : "after"
        return `${days} day${days === "1" ? "" : "s"} ${direction} Departure`
      }
      case "hours_before_departure":
      case "hours_after_departure": {
        const hours = this.groupValue(this.offsetHoursGroupTarget, "input")
        if (hours === "") return "Enter an hour offset."
        const direction = shape === "hours_before_departure" ? "before" : "after"
        return `${hours} hour${hours === "1" ? "" : "s"} ${direction} Departure`
      }
      case "earlier_of":
      case "later_of": {
        const word = shape === "earlier_of" ? "Earlier" : "Later"
        return `${word} of ${this.armPreview("arm1")} or ${this.armPreview("arm2")}`
      }
      default:
        return shape
    }
  }

  armPreview(prefix) {
    const shape = this[`${prefix}RuleShapeTarget`]?.value || ""
    if (!shape) return "arm not set"
    if (shape === "fixed_date") return this.groupValue(this[`${prefix}FixedDateGroupTarget`], "input") || "date"
    if (shape === "fixed_local_datetime") {
      return this.groupValue(this[`${prefix}FixedDatetimeGroupTarget`], "input") || "datetime"
    }
    if (shape.includes("days_")) {
      const days = this.groupValue(this[`${prefix}OffsetDaysGroupTarget`], "input")
      return days === "" ? "days" : `${days} days ${shape.includes("before") ? "before" : "after"} Departure`
    }
    if (shape.includes("hours_")) {
      const hours = this.groupValue(this[`${prefix}OffsetHoursGroupTarget`], "input")
      return hours === "" ? "hours" : `${hours} hours ${shape.includes("before") ? "before" : "after"} Departure`
    }
    return shape
  }

  coverageSentence() {
    const scope = this.coverageScopeTarget.value
    if (scope === "arrangement") return "Entire Cruise Arrangement"
    if (scope === "resource") {
      const select = this.resourceSelectTarget
      const label = select.options[select.selectedIndex]?.text || "cabin category"
      return select.value ? `Cabin category ${label}` : "Choose a cabin category"
    }
    if (scope === "capacity_pool") {
      const select = this.poolSelectTarget
      const label = select.options[select.selectedIndex]?.text || "Capacity Pool"
      return select.value ? `Capacity Pool ${label}` : "Choose a Capacity Pool"
    }
    return "Coverage not selected"
  }

  groupValue(group, selector) {
    const field = group.querySelector(selector)
    return field ? field.value : ""
  }

  setGroup(group, visible) {
    if (!group) return
    group.hidden = !visible
    group.querySelectorAll("input, select, textarea").forEach((field) => {
      field.disabled = !visible
    })
  }
}
