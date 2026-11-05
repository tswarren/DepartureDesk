import { Controller } from "@hotwired/stimulus"

// Shows a footer as it will render on documents (SET-07). The server renders
// it with the same allow-list the documents use.
export default class extends Controller {
  static targets = ["source", "output"]
  static values = { url: String }

  async preview(event) {
    event.preventDefault()
    const token = document.querySelector("meta[name='csrf-token']")?.content
    const body = new FormData()
    body.append("source", this.sourceTarget.value)
    const response = await fetch(this.urlValue, {
      method: "POST",
      body,
      headers: { "X-CSRF-Token": token, Accept: "text/html" },
      credentials: "same-origin"
    })
    this.outputTarget.innerHTML = response.ok ? await response.text() : ""
    this.outputTarget.hidden = false
  }
}
