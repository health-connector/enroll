import { Controller } from "@hotwired/stimulus"

// Drives the Pagy-backed datatables: serializes UI state into query params, fetches the server-rendered table fragment, and swaps it into the wrapper.
const SEARCH_DEBOUNCE_MS = 800
const MAX_FILTER_LEVELS = 4

export default class extends Controller {
  static targets = ["wrapper", "search", "processing"]
  static values = {
    url: String,
    page: { type: Number, default: 1 },
    per: { type: Number, default: 10 },
    search: { type: String, default: "" },
    order: { type: String, default: "" },
    dir: { type: String, default: "asc" }
  }

  connect() {
    this.bindLengthSelect()
  }

  disconnect() {
    clearTimeout(this.searchTimeout)
  }

  // --- chrome events (data-action attributes are re-rendered with each swap) ---

  searchChanged(event) {
    clearTimeout(this.searchTimeout)
    const value = event.currentTarget.value
    this.searchTimeout = setTimeout(() => {
      this.searchValue = value
      this.pageValue = 1
      this.redraw()
    }, SEARCH_DEBOUNCE_MS)
  }

  clearSearch() {
    clearTimeout(this.searchTimeout)
    if (this.hasSearchTarget) this.searchTarget.value = ""
    this.searchValue = ""
    this.pageValue = 1
    this.redraw()
  }

  perChanged(event) {
    this.perValue = parseInt(event.currentTarget.value, 10)
    this.pageValue = 1
    this.redraw()
  }

  pageClicked(event) {
    event.preventDefault()
    const item = event.currentTarget.closest("li")
    if (item && item.classList.contains("disabled")) return
    const page = parseInt(event.currentTarget.dataset.page, 10)
    if (!page || page === this.pageValue) return
    this.pageValue = page
    this.redraw()
  }

  sortClicked(event) {
    const column = event.currentTarget.dataset.column
    if (this.orderValue === column) {
      this.dirValue = this.dirValue === "asc" ? "desc" : "asc"
    } else {
      this.orderValue = column
      this.dirValue = "asc"
    }
    this.pageValue = 1
    this.redraw()
  }

  exportCsv(event) {
    event.preventDefault()
    const url = this.buildUrl("csv")
    url.searchParams.delete("page")
    url.searchParams.delete("per")
    window.location.assign(url)
  }

  // Filter tab behavior: one active tab per level, clicking hides deeper levels, an active tab reveals its Filter-<id> sub-level. Must stay equivalent to the legacy DT.filters() implementation while both stacks coexist.
  filterClicked(event) {
    const button = event.currentTarget
    const group = button.parentElement
    const levelMatch = /custom_level_(\d)/.exec(group.className)
    const level = levelMatch ? parseInt(levelMatch[1], 10) : 1
    this.clearFilterLevel(level + 1)

    if (button.classList.contains("active")) {
      button.classList.remove("active")
    } else {
      Array.from(group.children).forEach((sibling) => sibling.classList.remove("active"))
      button.classList.add("active")
      const filterId = button.id.substring(4).replace(/\//g, "-")
      this.element.querySelectorAll(`.Filter-${cssEscape(filterId)}`)
        .forEach((el) => el.classList.remove("hide"))
    }

    this.pageValue = 1
    this.redraw()
  }

  // --- redraw loop ---

  async redraw() {
    this.showProcessing()
    try {
      const response = await fetch(this.buildUrl("html"), {
        headers: { "X-Requested-With": "XMLHttpRequest", "Accept": "text/html" },
        credentials: "same-origin"
      })
      if (!response.ok) throw new Error(`datatable fragment failed: ${response.status}`)
      this.wrapperTarget.innerHTML = await response.text()
      this.applyLegacyDecorations()
      this.bindLengthSelect()
      this.element.dispatchEvent(new CustomEvent("effective-datatable:draw", { bubbles: true }))
    } catch (error) {
      this.hideProcessing()
      throw error
    }
  }

  buildUrl(format) {
    const url = new URL(this.urlValue, window.location.origin)
    if (format === "csv") url.pathname = `${url.pathname}.csv`
    url.searchParams.set("page", this.pageValue)
    url.searchParams.set("per", this.perValue)
    if (this.searchValue) url.searchParams.set("search", this.searchValue)
    if (this.orderValue) {
      url.searchParams.set("order", this.orderValue)
      url.searchParams.set("dir", this.dirValue)
    }
    const filters = this.filterParams()
    Object.keys(filters).forEach((key) => url.searchParams.set(key, filters[key]))
    return url
  }

  // Walks the active tab chain: each level's active button contributes <group data-scope> = <button data-key> — the same params the query wrappers have always received.
  filterParams(params = {}, level = 1) {
    if (level > MAX_FILTER_LEVELS) return params
    const active = this.element.querySelector(`.custom_level_${level} .active`)
    if (!active) return params
    params[active.parentElement.dataset.scope] = active.dataset.key
    return this.filterParams(params, level + 1)
  }

  clearFilterLevel(level) {
    if (level > MAX_FILTER_LEVELS) return
    this.element.querySelectorAll(`.custom_level_${level}`)
      .forEach((el) => el.classList.add("hide"))
    this.element.querySelectorAll(`.custom_level_${level} .btn-default`)
      .forEach((el) => el.classList.remove("active"))
    this.clearFilterLevel(level + 1)
  }

  // The length select can't use a Stimulus data-action: selectric (applied by
  // page-level scripts) hides the native select and propagates picks with
  // jQuery's .trigger('change'), which runs jQuery-bound handlers only — no
  // native DOM event is dispatched, so addEventListener never fires. A jQuery
  // binding hears both native changes and selectric's triggered ones; the
  // native fallback covers pages where jQuery is gone.
  bindLengthSelect() {
    const select = this.element.querySelector(".dataTables_length select")
    if (!select) return
    const $ = window.jQuery
    if ($) {
      $(select).off("change.datatable").on("change.datatable", (event) => this.perChanged(event))
    } else {
      select.addEventListener("change", (event) => this.perChanged(event))
    }
  }

  showProcessing() {
    if (this.hasProcessingTarget) this.processingTarget.style.display = "block"
  }

  hideProcessing() {
    if (this.hasProcessingTarget) this.processingTarget.style.display = "none"
  }

  // Coexistence glue: legacy page-level scripts decorate the initial DOM
  // (semantic_class() interaction-* classes, selectric select styling) on page
  // load only, so they are re-applied to freshly swapped chrome here. Both
  // calls no-op once the legacy scripts are retired.
  applyLegacyDecorations() {
    if (typeof window.semantic_class === "function") window.semantic_class()
    const $ = window.jQuery
    const select = this.element.querySelector(".dataTables_length select")
    if ($ && $.fn && $.fn.selectric && select) $(select).selectric()
  }
}

// CSS.escape fallback for the filter-id selector (ids contain no characters
// needing more than basic escaping, but Tab ids include user-defined scopes).
function cssEscape(value) {
  if (window.CSS && window.CSS.escape) return window.CSS.escape(value)
  return value.replace(/([^a-zA-Z0-9_-])/g, "\\$1")
}
