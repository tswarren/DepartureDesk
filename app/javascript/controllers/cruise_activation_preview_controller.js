import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["status", "list"]
  static values = {
    url: String,
    lockVersion: Number
  }

  refresh(event) {
    event.preventDefault()
    const token = document.querySelector("meta[name='csrf-token']")?.content
    const body = new URLSearchParams()
    body.set("version_lock_version", String(this.lockVersionValue))

    this.statusTarget.textContent = "Refreshing activation preview…"

    fetch(this.urlValue, {
      method: "POST",
      headers: {
        "X-CSRF-Token": token,
        Accept: "application/json",
        "Content-Type": "application/x-www-form-urlencoded"
      },
      body: body.toString(),
      credentials: "same-origin"
    })
      .then((response) => response.json())
      .then((payload) => this.renderPayload(payload))
      .catch(() => {
        this.statusTarget.textContent = "Could not refresh activation preview."
      })
  }

  renderPayload(payload) {
    if (payload.stale) {
      this.statusTarget.textContent = payload.blockers?.[0] || "Preview is stale. Refresh the page."
      return
    }

    const parts = []
    if (payload.elapsed_acknowledgment_required) {
      parts.push("Elapsed dates will require acknowledgment at activation.")
    }
    if (payload.blockers?.length) {
      parts.push(payload.blockers.join(" "))
    } else {
      parts.push("Preview is current.")
    }
    this.statusTarget.textContent = parts.join(" ")

    if (!this.hasListTarget) return

    this.listTarget.innerHTML = ""
    ;(payload.rows || []).forEach((row) => {
      const item = document.createElement("li")
      item.className = "dd-stack"
      const title = document.createElement("p")
      const strong = document.createElement("strong")
      strong.textContent = row.display_name
      title.appendChild(strong)
      title.appendChild(
        document.createTextNode(
          [
            "",
            row.amount_sentence,
            row.due_sentence,
            row.coverage_summary,
            row.will_open_commitment ? "Opens commitment" : "No commitment opening",
            row.elapsed_acknowledgment_required ? "Elapsed acknowledgment required" : null,
            row.blocker
          ]
            .filter(Boolean)
            .join(" · ")
        )
      )
      item.appendChild(title)
      if (row.editor_anchor) {
        const link = document.createElement("a")
        link.href = row.editor_anchor
        link.className = "dd-link"
        link.textContent = "Open definition"
        item.appendChild(link)
      }
      this.listTarget.appendChild(item)
    })
  }
}
