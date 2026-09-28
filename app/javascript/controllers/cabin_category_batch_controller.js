import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "rows", "template" ]

  add(event) {
    event.preventDefault()
    const fragment = this.templateTarget.content.cloneNode(true)
    const row = fragment.querySelector("[data-controller='cabin-category-row']")
    const index = this.rowsTarget.querySelectorAll("[data-controller='cabin-category-row']").length + 1
    const key = crypto.randomUUID()
    row.querySelector("[data-cabin-key]").value = key
    const legend = row.querySelector("legend")
    if (legend) legend.textContent = `Category ${index}`
    row.querySelectorAll("[id]").forEach((element) => {
      const nextId = `${element.id}_${index}`
      const label = row.querySelector(`label[for="${element.id}"]`)
      element.id = nextId
      if (label) label.htmlFor = nextId
    })
    this.rowsTarget.appendChild(fragment)
  }
}
