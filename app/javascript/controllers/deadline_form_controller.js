import { Controller } from "@hotwired/stimulus"

// Sums up a supplier deadline as it is filled in, and keeps "make a task"
// at the type's default until staff change it (SUP-22).
export default class extends Controller {
  static targets = ["type", "name", "date", "time", "zone", "task", "output"]
  static values = { labels: Object, defaults: Object, records: Object, supplier: String, owner: String, zone: String }

  connect() {
    this.touched = false
    this.update()
  }

  typeChanged() {
    if (!this.touched) this.taskTarget.checked = this.defaultsValue[this.typeTarget.value] !== false
    this.update()
  }

  taskTouched() {
    this.touched = true
  }

  update() {
    const type = this.typeTarget.value
    const name = this.nameTarget.value.trim() || this.labelsValue[type]
    const date = this.dateTarget.value
    if (!date) {
      this.outputTarget.textContent = "Choose what is due and when."
      return
    }
    const [year, month, day] = date.split("-").map(Number)
    const when = new Date(Date.UTC(year, month - 1, day)).toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric", timeZone: "UTC" })
    const time = this.timeTarget.value
    const zone = (time && this.zoneTarget.value) || this.zoneValue
    const at = time ? this.clock(time) : "11:59 p.m."
    let sentence = `${name} due to ${this.supplierValue} by ${at} on ${when}, ${zone.split("/").pop().replace(/_/g, " ")} time.`
    if (this.taskTarget.checked) {
      sentence += this.ownerValue ? ` A task for ${this.ownerValue}` : " A task for staff"
      const records = this.recordsValue[type]
      sentence += records ? `; completing it records that ${records}.` : "."
    } else {
      sentence += " Informational; no task."
    }
    this.outputTarget.textContent = sentence
  }

  clock(value) {
    const [hours, minutes] = value.split(":").map(Number)
    const suffix = hours >= 12 ? "p.m." : "a.m."
    return `${((hours + 11) % 12) + 1}:${String(minutes).padStart(2, "0")} ${suffix}`
  }
}
