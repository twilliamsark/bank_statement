import { Controller } from "@hotwired/stimulus"

// Text fields + custom suggestion menus (avoids flaky native datalist behavior).
export default class extends Controller {
  static targets = ["category", "subcategory", "categoryMenu", "subcategoryMenu"]
  static values = {
    options: { type: Object, default: {} },
    categories: { type: Array, default: [] },
    requireSubcategory: { type: Boolean, default: false }
  }

  connect() {
    this.previousCategory = this.#trimmed(this.categoryTarget.value)
    this.#syncSubcategoryEnabled()
    this._onPointerDown = this.#onDocumentPointerDown.bind(this)
    document.addEventListener("pointerdown", this._onPointerDown)
  }

  disconnect() {
    document.removeEventListener("pointerdown", this._onPointerDown)
  }

  categoryFocused() {
    this.#hideMenu(this.subcategoryMenuTarget)
    this.#showCategoryMenu()
  }

  categoryInput() {
    this.#syncSubcategoryEnabled()
    this.#showCategoryMenu(this.#trimmed(this.categoryTarget.value))
  }

  categoryKeydown(event) {
    if (event.key === "Escape") {
      this.#hideMenu(this.categoryMenuTarget)
    }
  }

  categoryChanged() {
    const nextCategory = this.#trimmed(this.categoryTarget.value)
    const previousCategory = this.#trimmed(this.previousCategory)
    this.previousCategory = nextCategory
    this.#hideMenu(this.categoryMenuTarget)

    if (nextCategory === previousCategory) {
      this.#syncSubcategoryEnabled()
      return
    }

    this.subcategoryTarget.value = ""
    this.#syncSubcategoryEnabled()

    if (!nextCategory) {
      this.#hideMenu(this.subcategoryMenuTarget)
      this.#submit()
      return
    }

    if (this.requireSubcategoryValue) {
      this.subcategoryTarget.focus()
      this.#showSubcategoryMenu()
      return
    }

    this.#submit()
  }

  subcategoryFocused() {
    if (!this.#trimmed(this.categoryTarget.value)) return
    this.#hideMenu(this.categoryMenuTarget)
    this.#showSubcategoryMenu()
  }

  subcategoryInput() {
    if (!this.#trimmed(this.categoryTarget.value)) return
    this.#showSubcategoryMenu(this.#trimmed(this.subcategoryTarget.value))
  }

  subcategoryKeydown(event) {
    if (event.key === "Escape") {
      this.#hideMenu(this.subcategoryMenuTarget)
    }
  }

  subcategoryChanged() {
    this.#hideMenu(this.subcategoryMenuTarget)
    if (!this.#trimmed(this.categoryTarget.value)) return
    if (this.requireSubcategoryValue && !this.#trimmed(this.subcategoryTarget.value)) return
    this.#submit()
  }

  pickCategory(event) {
    event.preventDefault()
    const value = event.currentTarget.dataset.value || ""
    this.categoryTarget.value = value
    this.#hideMenu(this.categoryMenuTarget)
    this.categoryTarget.dispatchEvent(new Event("change", { bubbles: true }))
  }

  pickSubcategory(event) {
    event.preventDefault()
    const value = event.currentTarget.dataset.value || ""
    this.subcategoryTarget.value = value
    this.#hideMenu(this.subcategoryMenuTarget)
    this.subcategoryTarget.dispatchEvent(new Event("change", { bubbles: true }))
  }

  #showCategoryMenu(filter = "") {
    const items = this.#filtered(this.categoriesValue, filter)
    this.#renderMenu(this.categoryMenuTarget, items, "pickCategory")
    this.#revealMenu(this.categoryMenuTarget)
  }

  #showSubcategoryMenu(filter = "") {
    const category = this.#trimmed(this.categoryTarget.value)
    const items = this.#filtered(this.optionsValue[category] || [], filter)
    this.#renderMenu(this.subcategoryMenuTarget, items, "pickSubcategory")
    this.#revealMenu(this.subcategoryMenuTarget)
  }

  #filtered(items, filter) {
    const needle = (filter || "").toLowerCase()
    if (!needle) return items
    return items.filter((item) => item.toLowerCase().includes(needle))
  }

  #renderMenu(menu, items, actionName) {
    menu.innerHTML = ""
    if (items.length === 0) {
      const empty = document.createElement("li")
      empty.className = "px-3 py-2 text-muted"
      empty.textContent = "No matches — type a new value"
      menu.append(empty)
      return
    }

    items.forEach((item) => {
      const li = document.createElement("li")
      const button = document.createElement("button")
      button.type = "button"
      button.className = "block w-full px-3 py-1.5 text-left text-ink hover:bg-brand-50"
      button.dataset.value = item
      button.dataset.action = `mousedown->category-subcategory#${actionName}`
      button.textContent = item
      li.append(button)
      menu.append(li)
    })
  }

  #revealMenu(menu) {
    menu.classList.remove("hidden")
  }

  #hideMenu(menu) {
    menu.classList.add("hidden")
  }

  #onDocumentPointerDown(event) {
    if (this.element.contains(event.target)) return
    this.#hideMenu(this.categoryMenuTarget)
    this.#hideMenu(this.subcategoryMenuTarget)
  }

  #syncSubcategoryEnabled() {
    const hasCategory = Boolean(this.#trimmed(this.categoryTarget.value))
    this.subcategoryTarget.disabled = !hasCategory
    this.subcategoryTarget.classList.toggle("opacity-50", !hasCategory)
    this.subcategoryTarget.classList.toggle("cursor-not-allowed", !hasCategory)
    this.subcategoryTarget.placeholder = hasCategory ? "Subcategory" : "Enter category first"

    if (!hasCategory) {
      this.subcategoryTarget.value = ""
      this.#hideMenu(this.subcategoryMenuTarget)
    }
  }

  #trimmed(value) {
    return (value || "").trim()
  }

  #submit() {
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
