import { Controller } from "@hotwired/stimulus"

// The new-choice form's presets: a kind fills in the role, scope and
// pattern, and a name when the field is still empty.
export default class extends Controller {
  static targets = ["name", "role", "scope", "pattern"]
  static values = { presets: Object }

  choose(event) {
    const preset = this.presetsValue[event.target.value]
    if (!preset) return

    this.roleTarget.value = preset.role
    this.scopeTarget.value = preset.scope
    this.patternTarget.value = preset.pattern
    if (preset.name && this.nameTarget.value.trim() === "") this.nameTarget.value = preset.name
  }
}
