import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.focus()
    requestAnimationFrame(() => this.element.focus())
  }

  focusField(event) {
    const href = event.currentTarget.getAttribute("href") || ""
    const id = href.startsWith("#") ? href.slice(1) : ""
    const target = id ? document.getElementById(id) : null
    if (!target) return

    event.preventDefault()
    this.openAncestorDetails(target)
    target.focus()
  }

  openAncestorDetails(target) {
    let node = target.parentElement
    while (node) {
      if (node.tagName === "DETAILS") node.open = true
      node = node.parentElement
    }
  }
}
