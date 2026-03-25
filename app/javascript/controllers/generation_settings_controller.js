import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="generation-settings"
export default class extends Controller {
  static targets = [
    "toggleButton",
    "toggleIcon",
    "panel",
    "jsonInput",
  ]

  connect() {
    this.expanded = false
  }

  toggle() {
    if (!this.hasPanelTarget) return

    this.expanded = !this.expanded
    this.panelTarget.style.display = this.expanded ? "block" : "none"

    if (this.hasToggleIconTarget) {
      this.toggleIconTarget.classList.toggle("bi-chevron-down", !this.expanded)
      this.toggleIconTarget.classList.toggle("bi-chevron-up", this.expanded)
    }
  }
}
