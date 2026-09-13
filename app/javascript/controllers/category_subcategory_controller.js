import { Controller } from "@hotwired/stimulus"

// Combobox-style category/subcategory with datalist suggestions + auto-submit.
export default class extends Controller {
  static targets = ["category", "subcategory", "subcategoryList"]
  static values = {
    options: { type: Object, default: {} },
    requireSubcategory: { type: Boolean, default: false }
  }

  connect() {
    this.#rebuildSubcategoryOptions({ clearIfInvalid: false })
    this.#syncSubcategoryEnabled()
  }

  // Mark the next focus as user-initiated. Turbo often restores focus after a
  // stream update; that should NOT clear the field (which looked like a blank
  // selection until blur restored the value).
  categoryPointerDown() {
    this.categoryFocusFromUser = true
  }

  subcategoryPointerDown() {
    this.subcategoryFocusFromUser = true
  }

  categoryInput() {
    this.#syncSubcategoryEnabled()
  }

  categoryFocused() {
    if (!this.categoryFocusFromUser) return
    this.categoryFocusFromUser = false

    this.categoryValueBeforeFocus = this.categoryTarget.value
    this.categoryTarget.value = ""
  }

  categoryBlurred() {
    if (!this.#trimmed(this.categoryTarget.value) && this.categoryValueBeforeFocus != null) {
      this.categoryTarget.value = this.categoryValueBeforeFocus
    }
  }

  categoryChanged() {
    const previousCategory = this.#trimmed(this.categoryValueBeforeFocus)
    const nextCategory = this.#trimmed(this.categoryTarget.value)
    this.categoryValueBeforeFocus = null

    // Focus+blur with no real edit can still fire change; ignore no-ops.
    if (nextCategory === previousCategory) {
      this.#syncSubcategoryEnabled()
      return
    }

    // Any real category change clears subcategory so the user picks a valid pair.
    this.subcategoryTarget.value = ""
    this.subcategoryValueBeforeFocus = null
    this.#rebuildSubcategoryOptions({ clearIfInvalid: false })
    this.#syncSubcategoryEnabled()

    if (!nextCategory) {
      this.#submit()
      return
    }

    if (this.requireSubcategoryValue) {
      return
    }

    this.#submit()
  }

  subcategoryFocused() {
    if (!this.subcategoryFocusFromUser) return
    this.subcategoryFocusFromUser = false

    if (!this.#trimmed(this.categoryTarget.value)) return

    this.#rebuildSubcategoryOptions({ clearIfInvalid: false })
    this.subcategoryValueBeforeFocus = this.subcategoryTarget.value
    this.subcategoryTarget.value = ""
  }

  subcategoryBlurred() {
    if (!this.#trimmed(this.subcategoryTarget.value) && this.subcategoryValueBeforeFocus != null) {
      this.subcategoryTarget.value = this.subcategoryValueBeforeFocus
    }
    this.subcategoryValueBeforeFocus = null
  }

  subcategoryChanged() {
    this.subcategoryValueBeforeFocus = null
    if (!this.#trimmed(this.categoryTarget.value)) {
      return
    }
    if (this.requireSubcategoryValue && !this.#trimmed(this.subcategoryTarget.value)) {
      return
    }
    this.#submit()
  }

  #syncSubcategoryEnabled() {
    const hasCategory = Boolean(this.#trimmed(this.categoryTarget.value))
    this.subcategoryTarget.disabled = !hasCategory
    this.subcategoryTarget.classList.toggle("opacity-50", !hasCategory)
    this.subcategoryTarget.classList.toggle("cursor-not-allowed", !hasCategory)
    this.subcategoryTarget.placeholder = hasCategory ? "Subcategory" : "Enter category first"

    if (!hasCategory) {
      this.subcategoryTarget.value = ""
      if (this.hasSubcategoryListTarget) {
        this.subcategoryListTarget.innerHTML = ""
      }
    }
  }

  #rebuildSubcategoryOptions({ clearIfInvalid }) {
    if (!this.hasSubcategoryListTarget) return

    const selectedCategory = this.#trimmed(this.categoryTarget.value)
    if (!selectedCategory) {
      this.subcategoryListTarget.innerHTML = ""
      return
    }

    const options = this.optionsValue[selectedCategory] || []
    const previous = this.#trimmed(this.subcategoryTarget.value)

    this.subcategoryListTarget.innerHTML = ""
    options.forEach((name) => {
      this.subcategoryListTarget.append(this.#option(name))
    })

    if (clearIfInvalid && previous && !options.includes(previous)) {
      this.subcategoryTarget.value = ""
    }
  }

  #option(value) {
    const option = document.createElement("option")
    option.value = value
    return option
  }

  #trimmed(value) {
    return (value || "").trim()
  }

  #submit() {
    // Disabled fields are omitted from form data; re-enable so cleared subcategory is sent.
    const wasDisabled = this.subcategoryTarget.disabled
    this.subcategoryTarget.disabled = false

    if (typeof this.element.requestSubmit === "function") {
      this.element.requestSubmit()
    } else {
      this.element.submit()
    }

    if (wasDisabled) {
      this.subcategoryTarget.disabled = true
    }
  }
}
