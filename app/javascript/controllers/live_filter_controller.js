import { Controller } from "@hotwired/stimulus"

// Debounced submit for description/amount; immediate submit for selects/dates.
export default class extends Controller {
  static values = { delay: { type: Number, default: 250 } }

  connect() {
    this.timeout = null
  }

  disconnect() {
    this.#clear()
  }

  queue() {
    this.#clear()
    this.timeout = setTimeout(() => this.#submit(), this.delayValue)
  }

  submitNow() {
    this.#clear()
    this.#submit()
  }

  #clear() {
    if (this.timeout) {
      clearTimeout(this.timeout)
      this.timeout = null
    }
  }

  #submit() {
    if (typeof this.element.requestSubmit === "function") {
      this.element.requestSubmit()
    } else {
      this.element.submit()
    }
  }
}
