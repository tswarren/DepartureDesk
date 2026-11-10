import { Controller } from "@hotwired/stimulus"

// A Print button for a summary page (UX audit decision 8): the browser
// prints it, or saves it as a PDF, using the print styles. Nothing is stored.
export default class extends Controller {
  print() {
    window.print()
  }
}
