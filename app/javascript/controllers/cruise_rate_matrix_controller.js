import { Controller } from "@hotwired/stimulus"

const STATIC_ROWS = [
  { key: "base_fare", label: "Base Fare", economic_role: "supplier_charge", static: true },
  { key: "nccf", label: "NCCF", economic_role: "supplier_charge", static: true },
  { key: "taxes_fees", label: "Taxes & Fees", economic_role: "supplier_charge", static: true },
  { key: "discount", label: "Discount", economic_role: "supplier_credit", static: true }
]

const FAMILIES = {
  every_traveler: { label: "Every Traveler", allowsCategory: true },
  first_second: { label: "First/Second", allowsCategory: true, from: 1, to: 2 },
  additional: { label: "Additional", allowsCategory: true, from: 3, to: null },
  bounded_positions: { label: "Bounded positions", allowsCategory: true, staffPositions: true },
  every_cabin: { label: "Every Cabin", allowsCategory: false },
  single_supplement: { label: "Single Supplement", allowsCategory: false }
}

const DEFAULT_PROFILES = [
  { key: "first_second", family: "first_second", category: null, occupancy_position_from: 1, occupancy_position_to: 2 },
  { key: "additional", family: "additional", category: null, occupancy_position_from: 3, occupancy_position_to: null },
  { key: "every_traveler", family: "every_traveler", category: null, occupancy_position_from: null, occupancy_position_to: null },
  { key: "every_cabin", family: "every_cabin", category: null, occupancy_position_from: null, occupancy_position_to: null },
  { key: "single_supplement", family: "single_supplement", category: null, occupancy_position_from: null, occupancy_position_to: null }
]

const PREVIEW_DEBOUNCE_MS = 350

// Dynamic Cruise Supplier rate-matrix builder. Browser subtotals and illustrations
// are advisory; the server remains authoritative on save.
export default class extends Controller {
  static targets = [
    "profileList",
    "profilePanel",
    "profileFamily",
    "profileCategory",
    "profileCategoryField",
    "profileBoundedFields",
    "profileFrom",
    "profileTo",
    "editProfileIndex",
    "narrowSelect",
    "profilePosition",
    "matrixHead",
    "matrixBody",
    "subtotalRow",
    "componentPanel",
    "componentLabel",
    "componentRole",
    "editRowKey",
    "commissionMethod",
    "commissionNotProvided",
    "commissionPercentagePanel",
    "commissionDollarPanel",
    "commissionSharedField",
    "commissionPercentageField",
    "commissionRates",
    "commissionAmounts",
    "commissionTreatments",
    "illustrations",
    "occupantEditor",
    "formFields",
    "overlapPanel"
  ]

  static values = {
    currency: { type: String, default: "USD" },
    previewUrl: String,
    maxOccupancy: { type: Number, default: 3 },
    categories: { type: Array, default: [] },
    initialState: Object
  }

  connect() {
    this.activeProfileIndex = 0
    this.editingProfileIndex = null
    this.previewTimer = null
    this.previewAbort = null
    this.state = this.buildState(this.initialStateValue)
    this.renderAll()
    this.schedulePreview()
  }

  disconnect() {
    if (this.previewTimer) window.clearTimeout(this.previewTimer)
    if (this.previewAbort) this.previewAbort.abort()
  }

  buildState(raw) {
    const source = raw && typeof raw === "object" ? raw : {}
    const profiles = Array.isArray(source.profiles) && source.profiles.length > 0
      ? source.profiles.map((profile) => this.normalizeProfile(profile))
      : DEFAULT_PROFILES.map((profile) => ({ ...profile }))
    const customRows = Array.isArray(source.customRows)
      ? source.customRows.map((row) => this.normalizeCustomRow(row))
      : []
    const cells = { ...(source.cells || {}) }
    const commissionSource = source.commission || {}
    const addCells = Array.isArray(commissionSource.addCells || commissionSource.add_cells)
      ? [...(commissionSource.addCells || commissionSource.add_cells)]
      : []
    const subtractCells = Array.isArray(commissionSource.subtractCells || commissionSource.subtract_cells)
      ? [...(commissionSource.subtractCells || commissionSource.subtract_cells)]
      : []
    const treatments = {}
    Object.keys(cells).forEach((cellKey) => {
      if (!this.isPopulated(cells[cellKey])) return
      if (addCells.includes(cellKey)) treatments[cellKey] = "include"
      else if (subtractCells.includes(cellKey)) treatments[cellKey] = "subtract"
      else treatments[cellKey] = "ignore"
    })
    const occupants = Array.isArray(source.occupants) ? [...source.occupants] : null

    return {
      profiles,
      customRows,
      cells,
      commission: {
        method: (commissionSource.method || "not_provided").toString(),
        shared: commissionSource.shared !== false && commissionSource.shared !== "0",
        percentage: (commissionSource.percentage || "").toString(),
        amounts: { ...(commissionSource.amounts || {}) },
        rates: { ...(commissionSource.rates || {}) }
      },
      treatments,
      occupants
    }
  }

  normalizeProfile(profile) {
    const family = (profile.family || profile.key || "every_traveler").toString()
    const category = profile.category ? profile.category.toString().trim() || null : null
    const from = profile.occupancy_position_from ?? profile.occupancyPositionFrom ?? FAMILIES[family]?.from ?? null
    const to = Object.prototype.hasOwnProperty.call(profile, "occupancy_position_to")
      ? profile.occupancy_position_to
      : (Object.prototype.hasOwnProperty.call(profile, "occupancyPositionTo")
        ? profile.occupancyPositionTo
        : (FAMILIES[family]?.to ?? null))
    const key = (profile.key || this.encodeProfileKey(family, category, from, to)).toString()
    return {
      key,
      family,
      category,
      occupancy_position_from: from,
      occupancy_position_to: to
    }
  }

  normalizeCustomRow(row) {
    return {
      key: (row.key || this.slugify(row.label || "custom")).toString(),
      label: (row.label || "").toString(),
      economic_role: (row.economic_role || row.economicRole || "supplier_charge").toString()
    }
  }

  encodeProfileKey(family, category, from, to) {
    let base
    if (family === "bounded_positions") {
      const start = Number.parseInt(from, 10)
      const end = to === null || to === undefined || to === "" ? null : Number.parseInt(to, 10)
      base = end ? `bounded_${start}_${end}` : `bounded_${start}`
    } else {
      base = family
    }
    if (!category) return base
    return `${base}__${category}`
  }

  slugify(label) {
    let slug = label.toString().trim().toLowerCase().replace(/[^a-z0-9]+/g, "_").replace(/^_+|_+$/g, "")
    if (!slug) slug = "custom"
    if (STATIC_ROWS.some((row) => row.key === slug)) slug = `custom_${slug}`
    return slug.slice(0, 63)
  }

  cellKey(rowKey, profileKey) {
    return `${rowKey}:${profileKey}`
  }

  isPopulated(value) {
    return value !== null && value !== undefined && value.toString().trim() !== ""
  }

  allRows() {
    return [
      ...STATIC_ROWS,
      ...this.state.customRows.map((row) => ({ ...row, static: false }))
    ]
  }

  profileLabel(profile) {
    const family = FAMILIES[profile.family]
    let base = family?.label || profile.family
    if (profile.family === "bounded_positions") {
      const from = profile.occupancy_position_from
      const to = profile.occupancy_position_to
      base = to ? `Positions ${from}–${to}` : `Position ${from}+`
    }
    return profile.category ? `${base} · ${profile.category}` : base
  }

  currencySymbolPrefix(role) {
    const currency = this.currencyValue || "USD"
    try {
      const parts = new Intl.NumberFormat(undefined, {
        style: "currency",
        currency,
        currencyDisplay: "narrowSymbol",
        minimumFractionDigits: 0,
        maximumFractionDigits: 0
      }).formatToParts(0)
      const symbol = parts.find((part) => part.type === "currency")?.value || currency
      return role === "supplier_credit" ? `−${symbol}` : symbol
    } catch (_error) {
      return role === "supplier_credit" ? `−${currency}` : currency
    }
  }

  formatMoney(amount) {
    const currency = this.currencyValue || "USD"
    try {
      return amount.toLocaleString(undefined, {
        style: "currency",
        currency,
        minimumFractionDigits: 2,
        maximumFractionDigits: 2
      })
    } catch (_error) {
      return `${currency} ${amount.toFixed(2)}`
    }
  }

  // --- Profile panel ---

  toggleProfilePanel(event) {
    event?.preventDefault()
    this.editingProfileIndex = null
    if (this.hasEditProfileIndexTarget) this.editProfileIndexTarget.value = ""
    if (this.hasProfileFamilyTarget) this.profileFamilyTarget.value = "first_second"
    if (this.hasProfileCategoryTarget) this.profileCategoryTarget.value = ""
    if (this.hasProfileFromTarget) this.profileFromTarget.value = "1"
    if (this.hasProfileToTarget) this.profileToTarget.value = ""
    this.syncProfilePanelFields()
    if (this.hasProfilePanelTarget) {
      this.profilePanelTarget.hidden = !this.profilePanelTarget.hidden
    }
  }

  cancelProfilePanel(event) {
    event?.preventDefault()
    if (this.hasProfilePanelTarget) this.profilePanelTarget.hidden = true
    this.editingProfileIndex = null
  }

  profileFamilyChanged() {
    this.syncProfilePanelFields()
  }

  syncProfilePanelFields() {
    const family = this.hasProfileFamilyTarget ? this.profileFamilyTarget.value : "first_second"
    const meta = FAMILIES[family] || FAMILIES.every_traveler
    if (this.hasProfileCategoryFieldTarget) {
      this.profileCategoryFieldTarget.hidden = !meta.allowsCategory
    }
    if (this.hasProfileBoundedFieldsTarget) {
      this.profileBoundedFieldsTarget.hidden = !meta.staffPositions
    }
  }

  confirmProfile(event) {
    event?.preventDefault()
    const family = this.profileFamilyTarget.value
    const meta = FAMILIES[family]
    if (!meta) return

    const category = meta.allowsCategory
      ? (this.profileCategoryTarget.value || "").trim() || null
      : null
    let from = meta.from ?? null
    let to = meta.to ?? null
    if (meta.staffPositions) {
      from = Number.parseInt(this.profileFromTarget.value, 10)
      if (!from || from < 1) {
        window.alert("Enter a starting occupancy position of 1 or greater.")
        return
      }
      const rawTo = (this.profileToTarget.value || "").trim()
      to = rawTo === "" ? null : Number.parseInt(rawTo, 10)
      if (to !== null && (Number.isNaN(to) || to < from)) {
        window.alert("Ending position must be at or after the start.")
        return
      }
    }

    const key = this.encodeProfileKey(family, category, from, to)
    const profile = {
      key,
      family,
      category,
      occupancy_position_from: from,
      occupancy_position_to: to
    }

    const editIndex = this.hasEditProfileIndexTarget && this.editProfileIndexTarget.value !== ""
      ? Number.parseInt(this.editProfileIndexTarget.value, 10)
      : null

    if (editIndex !== null && !Number.isNaN(editIndex) && this.state.profiles[editIndex]) {
      const previous = this.state.profiles[editIndex]
      if (previous.key !== key) {
        const duplicate = this.state.profiles.some((entry, index) => (
          index !== editIndex && entry.key === key
        ))
        if (duplicate) {
          window.alert("That rate profile is already in the schedule.")
          return
        }
        this.relabelProfileCells(previous.key, key)
      }
      this.state.profiles[editIndex] = profile
    } else {
      if (this.state.profiles.some((entry) => entry.key === key)) {
        window.alert("That rate profile is already in the schedule.")
        return
      }
      this.state.profiles.push(profile)
      this.activeProfileIndex = this.state.profiles.length - 1
    }

    if (this.hasProfilePanelTarget) this.profilePanelTarget.hidden = true
    this.editingProfileIndex = null
    this.renderAll()
    this.schedulePreview()
  }

  editProfile(event) {
    event.preventDefault()
    const index = Number.parseInt(event.currentTarget.dataset.profileIndex, 10)
    const profile = this.state.profiles[index]
    if (!profile) return

    this.editingProfileIndex = index
    if (this.hasEditProfileIndexTarget) this.editProfileIndexTarget.value = String(index)
    if (this.hasProfileFamilyTarget) this.profileFamilyTarget.value = profile.family
    if (this.hasProfileCategoryTarget) this.profileCategoryTarget.value = profile.category || ""
    if (this.hasProfileFromTarget) {
      this.profileFromTarget.value = profile.occupancy_position_from ?? "1"
    }
    if (this.hasProfileToTarget) {
      this.profileToTarget.value = profile.occupancy_position_to ?? ""
    }
    this.syncProfilePanelFields()
    if (this.hasProfilePanelTarget) this.profilePanelTarget.hidden = false
    this.profilePanelTarget?.scrollIntoView({ block: "nearest" })
  }

  moveProfileUp(event) {
    event.preventDefault()
    const index = Number.parseInt(event.currentTarget.dataset.profileIndex, 10)
    if (index <= 0) return
    const profiles = this.state.profiles
    ;[profiles[index - 1], profiles[index]] = [profiles[index], profiles[index - 1]]
    this.activeProfileIndex = index - 1
    this.renderAll()
    this.schedulePreview()
  }

  moveProfileDown(event) {
    event.preventDefault()
    const index = Number.parseInt(event.currentTarget.dataset.profileIndex, 10)
    if (index < 0 || index >= this.state.profiles.length - 1) return
    const profiles = this.state.profiles
    ;[profiles[index], profiles[index + 1]] = [profiles[index + 1], profiles[index]]
    this.activeProfileIndex = index + 1
    this.renderAll()
    this.schedulePreview()
  }

  removeProfile(event) {
    event.preventDefault()
    const index = Number.parseInt(event.currentTarget.dataset.profileIndex, 10)
    const profile = this.state.profiles[index]
    if (!profile) return
    if (this.state.profiles.length <= 1) {
      window.alert("Keep at least one rate profile.")
      return
    }

    const hasValues = this.profileHasValues(profile.key)
    if (hasValues && !window.confirm(
      `Remove “${this.profileLabel(profile)}” and discard its amounts and commission values?`
    )) {
      return
    }

    this.clearProfileData(profile.key)
    this.state.profiles.splice(index, 1)
    if (this.activeProfileIndex >= this.state.profiles.length) {
      this.activeProfileIndex = Math.max(0, this.state.profiles.length - 1)
    }
    this.renderAll()
    this.schedulePreview()
  }

  profileHasValues(profileKey) {
    const cellPrefix = `:${profileKey}`
    const hasCell = Object.entries(this.state.cells).some(([key, value]) => (
      key.endsWith(cellPrefix) && this.isPopulated(value)
    ))
    const amount = this.state.commission.amounts[profileKey]
    const rate = this.state.commission.rates[profileKey]
    return hasCell || this.isPopulated(amount) || this.isPopulated(rate)
  }

  clearProfileData(profileKey) {
    Object.keys(this.state.cells).forEach((key) => {
      if (key.endsWith(`:${profileKey}`)) delete this.state.cells[key]
    })
    Object.keys(this.state.treatments).forEach((key) => {
      if (key.endsWith(`:${profileKey}`)) delete this.state.treatments[key]
    })
    delete this.state.commission.amounts[profileKey]
    delete this.state.commission.rates[profileKey]
  }

  relabelProfileCells(oldKey, newKey) {
    const nextCells = {}
    Object.entries(this.state.cells).forEach(([key, value]) => {
      if (key.endsWith(`:${oldKey}`)) {
        const rowKey = key.slice(0, -(oldKey.length + 1))
        nextCells[this.cellKey(rowKey, newKey)] = value
      } else {
        nextCells[key] = value
      }
    })
    this.state.cells = nextCells

    const nextTreatments = {}
    Object.entries(this.state.treatments).forEach(([key, value]) => {
      if (key.endsWith(`:${oldKey}`)) {
        const rowKey = key.slice(0, -(oldKey.length + 1))
        nextTreatments[this.cellKey(rowKey, newKey)] = value
      } else {
        nextTreatments[key] = value
      }
    })
    this.state.treatments = nextTreatments

    if (Object.prototype.hasOwnProperty.call(this.state.commission.amounts, oldKey)) {
      this.state.commission.amounts[newKey] = this.state.commission.amounts[oldKey]
      delete this.state.commission.amounts[oldKey]
    }
    if (Object.prototype.hasOwnProperty.call(this.state.commission.rates, oldKey)) {
      this.state.commission.rates[newKey] = this.state.commission.rates[oldKey]
      delete this.state.commission.rates[oldKey]
    }
  }

  // --- Component rows ---

  toggleComponentPanel(event) {
    event?.preventDefault()
    if (this.hasEditRowKeyTarget) this.editRowKeyTarget.value = ""
    if (this.hasComponentLabelTarget) this.componentLabelTarget.value = ""
    if (this.hasComponentRoleTarget) this.componentRoleTarget.value = "supplier_charge"
    if (this.hasComponentPanelTarget) {
      this.componentPanelTarget.hidden = !this.componentPanelTarget.hidden
    }
  }

  cancelComponentPanel(event) {
    event?.preventDefault()
    if (this.hasComponentPanelTarget) this.componentPanelTarget.hidden = true
  }

  confirmComponent(event) {
    event?.preventDefault()
    const label = (this.componentLabelTarget.value || "").trim()
    if (!label) {
      window.alert("Enter a component description.")
      return
    }
    const role = this.componentRoleTarget.value || "supplier_charge"
    const editKey = this.hasEditRowKeyTarget ? this.editRowKeyTarget.value : ""

    if (editKey) {
      const row = this.state.customRows.find((entry) => entry.key === editKey)
      if (!row) return
      row.label = label
      if (row.economic_role !== role) {
        row.economic_role = role
        this.redefaultTreatmentsForRow(row.key, role)
      }
    } else {
      let key = this.slugify(label)
      const existing = new Set(this.state.customRows.map((row) => row.key))
      if (existing.has(key) || STATIC_ROWS.some((row) => row.key === key)) {
        key = `${key}_${Date.now().toString(36)}`
      }
      this.state.customRows.push({ key, label, economic_role: role })
    }

    if (this.hasComponentPanelTarget) this.componentPanelTarget.hidden = true
    this.renderAll()
    this.schedulePreview()
  }

  editComponent(event) {
    event.preventDefault()
    const key = event.currentTarget.dataset.rowKey
    const row = this.state.customRows.find((entry) => entry.key === key)
    if (!row) return
    if (this.hasEditRowKeyTarget) this.editRowKeyTarget.value = row.key
    if (this.hasComponentLabelTarget) this.componentLabelTarget.value = row.label
    if (this.hasComponentRoleTarget) this.componentRoleTarget.value = row.economic_role
    if (this.hasComponentPanelTarget) this.componentPanelTarget.hidden = false
  }

  changeRole(event) {
    event.preventDefault()
    const key = event.currentTarget.dataset.rowKey
    const row = this.state.customRows.find((entry) => entry.key === key)
    if (!row) return
    row.economic_role = row.economic_role === "supplier_credit" ? "supplier_charge" : "supplier_credit"
    this.redefaultTreatmentsForRow(row.key, row.economic_role)
    this.renderAll()
    this.schedulePreview()
  }

  redefaultTreatmentsForRow(rowKey, role) {
    this.state.profiles.forEach((profile) => {
      const key = this.cellKey(rowKey, profile.key)
      if (!this.isPopulated(this.state.cells[key])) {
        delete this.state.treatments[key]
        return
      }
      this.state.treatments[key] = role === "supplier_credit" ? "subtract" : "include"
    })
  }

  moveRowUp(event) {
    event.preventDefault()
    const key = event.currentTarget.dataset.rowKey
    const index = this.state.customRows.findIndex((row) => row.key === key)
    if (index <= 0) return
    const rows = this.state.customRows
    ;[rows[index - 1], rows[index]] = [rows[index], rows[index - 1]]
    this.renderAll()
  }

  moveRowDown(event) {
    event.preventDefault()
    const key = event.currentTarget.dataset.rowKey
    const index = this.state.customRows.findIndex((row) => row.key === key)
    if (index < 0 || index >= this.state.customRows.length - 1) return
    const rows = this.state.customRows
    ;[rows[index], rows[index + 1]] = [rows[index + 1], rows[index]]
    this.renderAll()
  }

  removeComponent(event) {
    event.preventDefault()
    const key = event.currentTarget.dataset.rowKey
    const row = this.state.customRows.find((entry) => entry.key === key)
    if (!row) return

    const hasValues = this.state.profiles.some((profile) => (
      this.isPopulated(this.state.cells[this.cellKey(key, profile.key)])
    ))
    const inCommission = Object.keys(this.state.treatments).some((cellKey) => (
      cellKey.startsWith(`${key}:`) && this.state.treatments[cellKey] !== "ignore"
    ))
    if ((hasValues || inCommission) && !window.confirm(
      `Remove “${row.label}” and discard its amounts and commission selections?`
    )) {
      return
    }

    this.state.customRows = this.state.customRows.filter((entry) => entry.key !== key)
    Object.keys(this.state.cells).forEach((cellKey) => {
      if (cellKey.startsWith(`${key}:`)) delete this.state.cells[cellKey]
    })
    Object.keys(this.state.treatments).forEach((cellKey) => {
      if (cellKey.startsWith(`${key}:`)) delete this.state.treatments[cellKey]
    })
    this.renderAll()
    this.schedulePreview()
  }

  // --- Cells & commission ---

  cellInput(event) {
    const input = event.currentTarget
    const rowKey = input.dataset.row
    const profileKey = input.dataset.profile
    const key = this.cellKey(rowKey, profileKey)
    const value = input.value
    if (this.isPopulated(value)) {
      this.state.cells[key] = value
      if (!this.state.treatments[key]) {
        const row = this.allRows().find((entry) => entry.key === rowKey)
        this.state.treatments[key] = row?.economic_role === "supplier_credit" ? "subtract" : "include"
      }
    } else {
      delete this.state.cells[key]
      delete this.state.treatments[key]
    }
    this.recalculateSubtotals()
    this.syncFormFields()
    this.renderCommissionTreatments()
    this.schedulePreview()
  }

  selectCommissionMethod(event) {
    const method = event.currentTarget.value
    this.state.commission.method = method
    this.renderCommissionPanels()
    this.syncFormFields()
    this.schedulePreview()
  }

  commissionSharedChanged(event) {
    this.state.commission.shared = event.currentTarget.checked
    this.renderCommissionPanels()
    this.syncFormFields()
    this.schedulePreview()
  }

  commissionPercentageInput(event) {
    this.state.commission.percentage = event.currentTarget.value
    this.syncFormFields()
    this.schedulePreview()
  }

  commissionRateInput(event) {
    const profileKey = event.currentTarget.dataset.profile
    this.state.commission.rates[profileKey] = event.currentTarget.value
    this.syncFormFields()
    this.schedulePreview()
  }

  commissionAmountInput(event) {
    const profileKey = event.currentTarget.dataset.profile
    this.state.commission.amounts[profileKey] = event.currentTarget.value
    this.syncFormFields()
    this.schedulePreview()
  }

  setCellTreatment(event) {
    const cellKey = event.currentTarget.dataset.cellKey
    if (!cellKey) return
    const active = event.currentTarget.dataset.activeTreatment
    if (event.currentTarget.type === "checkbox") {
      this.state.treatments[cellKey] = event.currentTarget.checked ? active : "ignore"
    } else {
      this.state.treatments[cellKey] = event.currentTarget.value
    }
    this.syncFormFields()
    this.schedulePreview()
  }

  // --- Narrow nav ---

  selectProfile() {
    if (!this.hasNarrowSelectTarget) return
    const keys = this.state.profiles.map((profile) => profile.key)
    const index = keys.indexOf(this.narrowSelectTarget.value)
    this.activeProfileIndex = index >= 0 ? index : 0
    this.showActiveProfile()
  }

  previousProfile(event) {
    event?.preventDefault()
    const count = this.state.profiles.length
    if (count === 0) return
    this.activeProfileIndex = (this.activeProfileIndex - 1 + count) % count
    this.syncNarrowSelect()
    this.showActiveProfile()
  }

  nextProfile(event) {
    event?.preventDefault()
    const count = this.state.profiles.length
    if (count === 0) return
    this.activeProfileIndex = (this.activeProfileIndex + 1) % count
    this.syncNarrowSelect()
    this.showActiveProfile()
  }

  syncNarrowSelect() {
    if (!this.hasNarrowSelectTarget) return
    const keys = this.state.profiles.map((profile) => profile.key)
    this.narrowSelectTarget.value = keys[this.activeProfileIndex] || keys[0] || ""
  }

  showActiveProfile() {
    const keys = this.state.profiles.map((profile) => profile.key)
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

  rebuildNarrowNav() {
    if (!this.hasNarrowSelectTarget) return
    const select = this.narrowSelectTarget
    const previous = select.value
    select.innerHTML = ""
    this.state.profiles.forEach((profile) => {
      const option = document.createElement("option")
      option.value = profile.key
      option.textContent = this.profileLabel(profile)
      select.appendChild(option)
    })
    const keys = this.state.profiles.map((profile) => profile.key)
    if (keys.includes(previous)) {
      select.value = previous
      this.activeProfileIndex = keys.indexOf(previous)
    } else if (this.activeProfileIndex >= keys.length) {
      this.activeProfileIndex = Math.max(0, keys.length - 1)
    }
    this.syncNarrowSelect()
    this.showActiveProfile()
  }

  // --- Occupants (multi-category illustrations) ---

  uniqueCategories() {
    const fromProfiles = this.state.profiles
      .map((profile) => profile.category)
      .filter(Boolean)
    const provided = Array.isArray(this.categoriesValue) ? this.categoriesValue : []
    return [...new Set([...provided, ...fromProfiles, "Adult", "Child"].filter(Boolean))]
  }

  multiCategoryMode() {
    const cats = new Set(
      this.state.profiles.map((profile) => profile.category).filter(Boolean)
    )
    return cats.size > 1
  }

  occupantChanged(event) {
    const position = Number.parseInt(event.currentTarget.dataset.position, 10)
    if (!this.state.occupants) {
      this.state.occupants = Array.from({ length: this.maxOccupancyValue || 3 }, () => "Adult")
    }
    this.state.occupants[position - 1] = event.currentTarget.value
    this.schedulePreview()
  }

  // --- Render ---

  renderAll() {
    this.renderProfileList()
    this.renderMatrix()
    this.renderCommissionPanels()
    this.renderCommissionTreatments()
    this.renderOccupantEditor()
    this.rebuildNarrowNav()
    this.recalculateSubtotals()
    this.syncFormFields()
    this.updateOverlapVisibility()
  }

  renderProfileList() {
    if (!this.hasProfileListTarget) return
    const rows = this.state.profiles.map((profile, index) => {
      const applies = this.appliesLabel(profile)
      return `
        <tr>
          <td>${this.escape(this.profileLabel(profile))}</td>
          <td>${this.escape(profile.category || "—")}</td>
          <td>${this.escape(applies)}</td>
          <td>
            <div class="dd-actions">
              <button type="button" class="dd-button dd-button-secondary" data-action="cruise-rate-matrix#editProfile" data-profile-index="${index}">Edit</button>
              <button type="button" class="dd-button dd-button-secondary" data-action="cruise-rate-matrix#moveProfileUp" data-profile-index="${index}" ${index === 0 ? "disabled" : ""}>Move up</button>
              <button type="button" class="dd-button dd-button-secondary" data-action="cruise-rate-matrix#moveProfileDown" data-profile-index="${index}" ${index >= this.state.profiles.length - 1 ? "disabled" : ""}>Move down</button>
              <button type="button" class="dd-button dd-button-secondary" data-action="cruise-rate-matrix#removeProfile" data-profile-index="${index}">Remove</button>
            </div>
          </td>
        </tr>
      `
    }).join("")

    this.profileListTarget.innerHTML = `
      <div class="dd-table-wrap">
        <table class="dd-table">
          <thead>
            <tr>
              <th scope="col">Profile</th>
              <th scope="col">Traveler category</th>
              <th scope="col">Applies to</th>
              <th scope="col"><span class="dd-visually-hidden">Actions</span></th>
            </tr>
          </thead>
          <tbody>${rows || `<tr><td colspan="4">No rate profiles yet. Add one to begin.</td></tr>`}</tbody>
        </table>
      </div>
    `
  }

  appliesLabel(profile) {
    switch (profile.family) {
      case "first_second":
        return "Positions 1–2"
      case "additional":
        return "Positions 3+"
      case "bounded_positions": {
        const to = profile.occupancy_position_to
        return to
          ? `Positions ${profile.occupancy_position_from}–${to}`
          : `Position ${profile.occupancy_position_from}+`
      }
      case "every_traveler":
        return "Each traveler"
      case "every_cabin":
        return "Each cabin"
      case "single_supplement":
        return "Single cabin"
      default:
        return "—"
    }
  }

  renderMatrix() {
    if (!this.hasMatrixHeadTarget || !this.hasMatrixBodyTarget) return
    const profiles = this.state.profiles
    this.matrixHeadTarget.innerHTML = `
      <tr>
        <th scope="col">Component</th>
        ${profiles.map((profile) => `
          <th scope="col" data-profile-column="${this.escapeAttr(profile.key)}">
            ${this.escape(this.profileLabel(profile))}
          </th>
        `).join("")}
      </tr>
    `

    const bodyRows = this.allRows().map((row) => {
      const labelCell = row.static
        ? this.escape(row.label)
        : `
          <div class="dd-stack">
            <span>${this.escape(row.label)}</span>
            <span class="dd-help">${row.economic_role === "supplier_credit" ? "Supplier credit" : "Supplier charge"}</span>
            <div class="dd-actions">
              <button type="button" class="dd-button dd-button-secondary" data-action="cruise-rate-matrix#editComponent" data-row-key="${this.escapeAttr(row.key)}">Edit</button>
              <button type="button" class="dd-button dd-button-secondary" data-action="cruise-rate-matrix#changeRole" data-row-key="${this.escapeAttr(row.key)}">
                ${row.economic_role === "supplier_credit" ? "Make charge" : "Make credit"}
              </button>
              <button type="button" class="dd-button dd-button-secondary" data-action="cruise-rate-matrix#moveRowUp" data-row-key="${this.escapeAttr(row.key)}">Up</button>
              <button type="button" class="dd-button dd-button-secondary" data-action="cruise-rate-matrix#moveRowDown" data-row-key="${this.escapeAttr(row.key)}">Down</button>
              <button type="button" class="dd-button dd-button-secondary" data-action="cruise-rate-matrix#removeComponent" data-row-key="${this.escapeAttr(row.key)}">Remove</button>
            </div>
          </div>
        `

      const cells = profiles.map((profile) => {
        const key = this.cellKey(row.key, profile.key)
        const value = this.state.cells[key] || ""
        const prefix = this.currencySymbolPrefix(row.economic_role)
        return `
          <td data-profile-column="${this.escapeAttr(profile.key)}">
            <label class="dd-visually-hidden" for="cell_${this.escapeAttr(key.replace(/:/g, "_"))}">
              ${this.escape(row.label)} · ${this.escape(this.profileLabel(profile))}
            </label>
            <div class="dd-cruise-rate-cell">
              <span aria-hidden="true">${this.escape(prefix)}</span>
              <input type="text" class="dd-input" inputmode="decimal"
                id="cell_${this.escapeAttr(key.replace(/:/g, "_"))}"
                name="cells[${this.escapeAttr(key)}]"
                value="${this.escapeAttr(value)}"
                data-action="input->cruise-rate-matrix#cellInput"
                data-row="${this.escapeAttr(row.key)}"
                data-profile="${this.escapeAttr(profile.key)}"
                data-role="${this.escapeAttr(row.economic_role)}">
            </div>
          </td>
        `
      }).join("")

      return `<tr data-row-key="${this.escapeAttr(row.key)}"><th scope="row">${labelCell}</th>${cells}</tr>`
    }).join("")

    const subtotalCells = profiles.map((profile) => `
      <td data-profile-column="${this.escapeAttr(profile.key)}"
          data-cruise-rate-matrix-target="subtotal"
          data-profile="${this.escapeAttr(profile.key)}">—</td>
    `).join("")

    this.matrixBodyTarget.innerHTML = `
      ${bodyRows}
      <tr data-cruise-rate-matrix-target="subtotalRow">
        <th scope="row">Known profile subtotal</th>
        ${subtotalCells}
      </tr>
    `
  }

  recalculateSubtotals() {
    const totals = {}
    this.allRows().forEach((row) => {
      this.state.profiles.forEach((profile) => {
        const key = this.cellKey(row.key, profile.key)
        const raw = (this.state.cells[key] || "").toString().replace(/,/g, "").trim()
        if (raw === "") return
        const amount = Number.parseFloat(raw)
        if (Number.isNaN(amount)) return
        totals[profile.key] ||= 0
        totals[profile.key] += row.economic_role === "supplier_credit" ? -amount : amount
      })
    })

    this.element.querySelectorAll("[data-cruise-rate-matrix-target='subtotal']").forEach((cell) => {
      const profile = cell.dataset.profile
      if (!(profile in totals)) {
        cell.textContent = "—"
        return
      }
      cell.textContent = this.formatMoney(totals[profile])
    })
  }

  renderCommissionPanels() {
    const method = this.state.commission.method || "not_provided"
    if (this.hasCommissionMethodTarget) {
      this.commissionMethodTarget.value = method
    }
    if (this.hasCommissionNotProvidedTarget) {
      this.commissionNotProvidedTarget.hidden = method !== "not_provided"
    }
    if (this.hasCommissionPercentagePanelTarget) {
      this.commissionPercentagePanelTarget.hidden = method !== "percentage"
    }
    if (this.hasCommissionDollarPanelTarget) {
      this.commissionDollarPanelTarget.hidden = method !== "dollar"
    }

    if (this.hasCommissionSharedFieldTarget) {
      this.commissionSharedFieldTarget.checked = this.state.commission.shared
    }
    if (this.hasCommissionPercentageFieldTarget) {
      this.commissionPercentageFieldTarget.value = this.state.commission.percentage || ""
      this.commissionPercentageFieldTarget.disabled = !this.state.commission.shared
    }

    if (this.hasCommissionRatesTarget) {
      this.commissionRatesTarget.hidden = this.state.commission.shared
      this.commissionRatesTarget.innerHTML = this.state.profiles.map((profile) => `
        <div class="dd-field">
          <label class="dd-label" for="commission_rate_${this.escapeAttr(profile.key.replace(/:/g, "_"))}">
            ${this.escape(this.profileLabel(profile))}
          </label>
          <input type="text" class="dd-input" inputmode="decimal"
            id="commission_rate_${this.escapeAttr(profile.key.replace(/:/g, "_"))}"
            value="${this.escapeAttr(this.state.commission.rates[profile.key] || "")}"
            data-profile="${this.escapeAttr(profile.key)}"
            data-action="input->cruise-rate-matrix#commissionRateInput"
            ${this.state.commission.shared ? "disabled" : ""}>
        </div>
      `).join("")
    }

    if (this.hasCommissionAmountsTarget) {
      this.commissionAmountsTarget.innerHTML = this.state.profiles.map((profile) => `
        <div class="dd-field">
          <label class="dd-label" for="commission_amount_${this.escapeAttr(profile.key.replace(/:/g, "_"))}">
            ${this.escape(this.profileLabel(profile))}
          </label>
          <input type="text" class="dd-input" inputmode="decimal"
            id="commission_amount_${this.escapeAttr(profile.key.replace(/:/g, "_"))}"
            value="${this.escapeAttr(this.state.commission.amounts[profile.key] || "")}"
            data-profile="${this.escapeAttr(profile.key)}"
            data-action="input->cruise-rate-matrix#commissionAmountInput">
        </div>
      `).join("")
    }
  }

  renderCommissionTreatments() {
    if (!this.hasCommissionTreatmentsTarget) return
    const method = this.state.commission.method
    if (method !== "percentage") {
      this.commissionTreatmentsTarget.innerHTML = ""
      this.commissionTreatmentsTarget.hidden = true
      return
    }
    this.commissionTreatmentsTarget.hidden = false

    const populated = []
    this.allRows().forEach((row) => {
      this.state.profiles.forEach((profile) => {
        const key = this.cellKey(row.key, profile.key)
        if (!this.isPopulated(this.state.cells[key])) return
        populated.push({ key, row, profile })
      })
    })

    if (populated.length === 0) {
      this.commissionTreatmentsTarget.innerHTML = `<p class="dd-help">Populate rate cells to choose Include or Subtract treatments.</p>`
      return
    }

    this.commissionTreatmentsTarget.innerHTML = `
      <p class="dd-label">Which amounts affect the commissionable base?</p>
      <p class="dd-help">Charges: check Include. Credits: check Subtract. Unchecked means Ignore.</p>
      <div class="dd-table-wrap">
        <table class="dd-table">
          <thead>
            <tr>
              <th scope="col">Component</th>
              <th scope="col">Profile</th>
              <th scope="col">Treatment</th>
            </tr>
          </thead>
          <tbody>
            ${populated.map(({ key, row, profile }) => {
              const treatment = this.state.treatments[key] || (
                row.economic_role === "supplier_credit" ? "subtract" : "include"
              )
              const isCredit = row.economic_role === "supplier_credit"
              const active = isCredit ? "subtract" : "include"
              const label = isCredit ? "Subtract" : "Include"
              const checked = treatment === active
              const inputId = `treatment_${key.replace(/[^a-zA-Z0-9]+/g, "_")}`
              return `
                <tr>
                  <td>${this.escape(row.label)}</td>
                  <td>${this.escape(this.profileLabel(profile))}</td>
                  <td>
                    <label for="${this.escapeAttr(inputId)}">
                      <input type="checkbox" id="${this.escapeAttr(inputId)}"
                        data-cell-key="${this.escapeAttr(key)}"
                        data-active-treatment="${active}"
                        data-action="change->cruise-rate-matrix#setCellTreatment"
                        ${checked ? "checked" : ""}>
                      ${label}
                    </label>
                  </td>
                </tr>
              `
            }).join("")}
          </tbody>
        </table>
      </div>
    `
  }

  renderOccupantEditor() {
    if (!this.hasOccupantEditorTarget) return
    if (!this.multiCategoryMode()) {
      this.occupantEditorTarget.hidden = true
      this.occupantEditorTarget.innerHTML = ""
      this.state.occupants = null
      return
    }

    this.occupantEditorTarget.hidden = false
    const max = Math.max(1, this.maxOccupancyValue || 3)
    if (!this.state.occupants || this.state.occupants.length !== max) {
      this.state.occupants = Array.from({ length: max }, (_unused, index) => (
        (this.state.occupants && this.state.occupants[index]) || "Adult"
      ))
    }
    const categories = this.uniqueCategories()
    this.occupantEditorTarget.innerHTML = `
      <p class="dd-label">Anonymous occupants by position</p>
      <p class="dd-help">Used only for live illustrations. Not a forecast occupancy plan.</p>
      ${this.state.occupants.map((value, index) => `
        <div class="dd-field">
          <label class="dd-label" for="occupant_pos_${index + 1}">Position ${index + 1}</label>
          <select class="dd-input" id="occupant_pos_${index + 1}"
            data-position="${index + 1}"
            data-action="change->cruise-rate-matrix#occupantChanged">
            ${categories.map((category) => `
              <option value="${this.escapeAttr(category)}" ${value === category ? "selected" : ""}>
                ${this.escape(category)}
              </option>
            `).join("")}
          </select>
        </div>
      `).join("")}
    `
  }

  updateOverlapVisibility() {
    if (!this.hasOverlapPanelTarget) return
    const overlaps = this.detectCategoryOverlaps()
    this.overlapPanelTarget.hidden = overlaps.length === 0
  }

  detectCategoryOverlaps() {
    const decoded = this.state.profiles.map((profile) => ({ ...profile }))
    const overlaps = []
    for (let i = 0; i < decoded.length; i += 1) {
      for (let j = i + 1; j < decoded.length; j += 1) {
        const left = decoded[i]
        const right = decoded[j]
        if (!this.positionRangesOverlap(left, right)) continue
        const leftFree = !left.category
        const rightFree = !right.category
        if (leftFree === rightFree) continue
        if (!(leftFree || rightFree)) continue
        overlaps.push([left, right])
      }
    }
    return overlaps
  }

  positionRangesOverlap(left, right) {
    const leftMeta = FAMILIES[left.family]
    const rightMeta = FAMILIES[right.family]
    if (!leftMeta?.allowsCategory || !rightMeta?.allowsCategory) return false
    if (![ "first_second", "additional", "bounded_positions" ].includes(left.family)) return false
    if (![ "first_second", "additional", "bounded_positions" ].includes(right.family)) return false
    const fromA = left.occupancy_position_from ?? leftMeta.from
    const toA = left.occupancy_position_to ?? leftMeta.to ?? Infinity
    const fromB = right.occupancy_position_from ?? rightMeta.from
    const toB = right.occupancy_position_to ?? rightMeta.to ?? Infinity
    if (fromA == null || fromB == null) return false
    return fromA <= (toB ?? Infinity) && fromB <= (toA ?? Infinity)
  }

  // --- Form mirror ---

  syncFormFields() {
    if (!this.hasFormFieldsTarget) return
    const parts = []

    this.state.profiles.forEach((profile, index) => {
      parts.push(this.hiddenInput(`profiles[${index}][key]`, profile.key))
      parts.push(this.hiddenInput(`profiles[${index}][family]`, profile.family))
      parts.push(this.hiddenInput(`profiles[${index}][category]`, profile.category || ""))
      if (profile.occupancy_position_from != null && profile.occupancy_position_from !== "") {
        parts.push(this.hiddenInput(
          `profiles[${index}][occupancy_position_from]`,
          profile.occupancy_position_from
        ))
      }
      if (profile.occupancy_position_to != null && profile.occupancy_position_to !== "") {
        parts.push(this.hiddenInput(
          `profiles[${index}][occupancy_position_to]`,
          profile.occupancy_position_to
        ))
      }
    })

    this.state.customRows.forEach((row, index) => {
      parts.push(this.hiddenInput(`custom_rows[${index}][key]`, row.key))
      parts.push(this.hiddenInput(`custom_rows[${index}][label]`, row.label))
      parts.push(this.hiddenInput(`custom_rows[${index}][economic_role]`, row.economic_role))
    })

    // Visible cell inputs already carry names="cells[...]". Still mirror blanks out of
    // removed columns by clearing orphaned named fields via exclusive mirror for commission.
    parts.push(this.hiddenInput("commission[method]", this.state.commission.method))
    parts.push(this.hiddenInput("commission[shared]", this.state.commission.shared ? "1" : "0"))
    if (this.state.commission.method === "percentage") {
      if (this.state.commission.shared) {
        parts.push(this.hiddenInput("commission[percentage]", this.state.commission.percentage || ""))
      } else {
        this.state.profiles.forEach((profile) => {
          parts.push(this.hiddenInput(
            `commission[rates][${profile.key}]`,
            this.state.commission.rates[profile.key] || ""
          ))
        })
      }
      Object.entries(this.state.treatments).forEach(([cellKey, treatment]) => {
        if (treatment === "include") {
          parts.push(this.hiddenInput("commission[add_cells][]", cellKey))
        } else if (treatment === "subtract") {
          parts.push(this.hiddenInput("commission[subtract_cells][]", cellKey))
        }
      })
    } else if (this.state.commission.method === "dollar") {
      this.state.profiles.forEach((profile) => {
        parts.push(this.hiddenInput(
          `commission[amounts][${profile.key}]`,
          this.state.commission.amounts[profile.key] || ""
        ))
      })
    }

    this.formFieldsTarget.innerHTML = parts.join("")
  }

  hiddenInput(name, value) {
    return `<input type="hidden" name="${this.escapeAttr(name)}" value="${this.escapeAttr(value ?? "")}">`
  }

  // --- Live preview ---

  schedulePreview() {
    if (!this.previewUrlValue) return
    if (this.previewTimer) window.clearTimeout(this.previewTimer)
    this.previewTimer = window.setTimeout(() => this.fetchPreview(), PREVIEW_DEBOUNCE_MS)
  }

  async fetchPreview() {
    if (!this.previewUrlValue) return
    if (this.previewAbort) this.previewAbort.abort()
    this.previewAbort = new AbortController()

    const form = this.element.closest("form") || this.element.querySelector("form")
    const payload = new FormData()
    const contextKeys = new Set([
      "authenticity_token",
      "version_lock_version",
      "definition_lock_version",
      "stage",
      "convert_legacy",
      "notes",
      "overlap_resolution"
    ])
    if (form) {
      new FormData(form).forEach((value, key) => {
        if (contextKeys.has(key) || key.startsWith("profiles") ||
            key.startsWith("custom_rows") || key.startsWith("cells") ||
            key.startsWith("commission") || key.startsWith("illustration_occupants")) {
          payload.append(key, value)
        }
      })
    }
    this.appendStateToFormData(payload)

    const token = document.querySelector("meta[name='csrf-token']")?.content
    try {
      const response = await fetch(this.previewUrlValue, {
        method: "POST",
        headers: {
          Accept: "application/json",
          "X-CSRF-Token": token || "",
          "X-Requested-With": "XMLHttpRequest"
        },
        body: payload,
        credentials: "same-origin",
        signal: this.previewAbort.signal
      })
      const data = await response.json()
      this.renderIllustrations(data)
    } catch (error) {
      if (error.name === "AbortError") return
      if (this.hasIllustrationsTarget) {
        this.illustrationsTarget.innerHTML = `<p class="dd-help" role="status">Illustration preview unavailable.</p>`
      }
    }
  }

  appendStateToFormData(payload) {
    // Ensure latest mirrored fields win even if FormData missed dynamic inputs.
    this.state.profiles.forEach((profile, index) => {
      payload.set(`profiles[${index}][key]`, profile.key)
      payload.set(`profiles[${index}][family]`, profile.family)
      payload.set(`profiles[${index}][category]`, profile.category || "")
      if (profile.occupancy_position_from != null && profile.occupancy_position_from !== "") {
        payload.set(`profiles[${index}][occupancy_position_from]`, String(profile.occupancy_position_from))
      }
      if (profile.occupancy_position_to != null && profile.occupancy_position_to !== "") {
        payload.set(`profiles[${index}][occupancy_position_to]`, String(profile.occupancy_position_to))
      }
    })
    this.state.customRows.forEach((row, index) => {
      payload.set(`custom_rows[${index}][key]`, row.key)
      payload.set(`custom_rows[${index}][label]`, row.label)
      payload.set(`custom_rows[${index}][economic_role]`, row.economic_role)
    })
    Object.entries(this.state.cells).forEach(([key, value]) => {
      payload.set(`cells[${key}]`, value)
    })
    payload.set("commission[method]", this.state.commission.method)
    payload.set("commission[shared]", this.state.commission.shared ? "1" : "0")
    if (this.state.commission.method === "percentage") {
      if (this.state.commission.shared) {
        payload.set("commission[percentage]", this.state.commission.percentage || "")
      } else {
        this.state.profiles.forEach((profile) => {
          payload.set(
            `commission[rates][${profile.key}]`,
            this.state.commission.rates[profile.key] || ""
          )
        })
      }
      Object.entries(this.state.treatments).forEach(([cellKey, treatment]) => {
        if (treatment === "include") payload.append("commission[add_cells][]", cellKey)
        if (treatment === "subtract") payload.append("commission[subtract_cells][]", cellKey)
      })
    } else if (this.state.commission.method === "dollar") {
      this.state.profiles.forEach((profile) => {
        payload.set(
          `commission[amounts][${profile.key}]`,
          this.state.commission.amounts[profile.key] || ""
        )
      })
    }

    if (Array.isArray(this.state.occupants)) {
      this.state.occupants.forEach((label, index) => {
        payload.set(`illustration_occupants[${index}]`, label || "")
      })
    }
  }

  renderIllustrations(data) {
    if (!this.hasIllustrationsTarget) return
    if (data.error && (!data.illustrations || data.illustrations.length === 0)) {
      this.illustrationsTarget.innerHTML = `<p class="dd-help" role="status">${this.escape(data.error)}</p>`
      return
    }
    const rows = Array.isArray(data.illustrations) ? data.illustrations : []
    if (rows.length === 0) {
      this.illustrationsTarget.innerHTML = `<p class="dd-help">Enter amounts to see per-cabin illustrations.</p>`
      return
    }
    this.illustrationsTarget.innerHTML = `
      <div class="dd-table-wrap">
        <table class="dd-table">
          <thead>
            <tr>
              <th scope="col">Illustration</th>
              <th scope="col">Gross Supplier cost</th>
              <th scope="col">Commission</th>
              <th scope="col">Net after commission</th>
            </tr>
          </thead>
          <tbody>
            ${rows.map((row) => `
              <tr>
                <td>${this.escape(row.label)}</td>
                <td>${this.escape(row.gross || "Pending")}</td>
                <td>${this.escape(row.commission || row.commission_state || "Pending")}</td>
                <td>${this.escape(row.net || row.net_state || "Pending")}</td>
              </tr>
            `).join("")}
          </tbody>
        </table>
      </div>
      <p class="dd-help">Values update as rate or commission fields change. Server-calculated values govern on save.</p>
    `
  }

  escape(value) {
    return String(value ?? "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
  }

  escapeAttr(value) {
    return this.escape(value).replace(/'/g, "&#39;")
  }
}
