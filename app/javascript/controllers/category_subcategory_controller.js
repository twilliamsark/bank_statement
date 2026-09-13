import { Controller } from "@hotwired/stimulus"

// Dependent subcategory options + auto-submit on change.
export default class extends Controller {
  static targets = ["category", "subcategory"]
  static values = {
    options: { type: Object, default: {} },
    requireSubcategory: { type: Boolean, default: false }
  }

  categoryChanged() {
    this.#rebuildSubcategoryOptions()
    if (this.requireSubcategoryValue && !this.subcategoryTarget.value) {
      return
    }
    this.#submit()
  }

  subcategoryChanged() {
    if (this.requireSubcategoryValue && !this.subcategoryTarget.value) {
      return
    }
    this.#submit()
  }

  #rebuildSubcategoryOptions() {
    const selectedCategory = this.categoryTarget.value
    const options = this.optionsValue[selectedCategory] || []
    const previous = this.subcategoryTarget.value

    this.subcategoryTarget.innerHTML = ""
    this.subcategoryTarget.append(this.#option("", "—"))

    options.forEach((name) => {
      this.subcategoryTarget.append(this.#option(name, name))
    })

    if (options.includes(previous)) {
      this.subcategoryTarget.value = previous
    } else {
      this.subcategoryTarget.value = ""
    }
  }

  #option(value, label) {
    const option = document.createElement("option")
    option.value = value
    option.textContent = label
    return option
  }

  #submit() {
    if (typeof this.element.requestSubmit === "function") {
      this.element.requestSubmit()
    } else {
      this.element.submit()
    }
  }
}
