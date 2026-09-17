import { Controller } from "@hotwired/stimulus"
import axios from "axios"

// Drives the employer bulk-actions dropdown. The checkbox column, the dropdown,
// and the processing panel all live inside the wrapper the datatable controller
// swaps on redraw, so this controller (scoped to the persistent container)
// listens by event delegation and re-applies row state on every draw rather than
// holding Stimulus targets.
const MESSAGE_VISIBLE_MS = 2000
const ALL_ROLE = "input[data-role='bulk-actions-all']"
const RESOURCE_ROLE = "input[data-role='bulk-actions-resource']"
const LINK_SELECTOR = ".buttons-bulk-actions a"

export default class extends Controller {
  connect() {
    this.onChange = this.onChange.bind(this)
    this.onClick = this.onClick.bind(this)
    this.onDraw = this.refresh.bind(this)
    this.element.addEventListener("change", this.onChange)
    this.element.addEventListener("click", this.onClick)
    this.element.addEventListener("effective-datatable:draw", this.onDraw)
    this.refresh()
  }

  disconnect() {
    this.element.removeEventListener("change", this.onChange)
    this.element.removeEventListener("click", this.onClick)
    this.element.removeEventListener("effective-datatable:draw", this.onDraw)
  }

  onChange(event) {
    if (event.target.matches(ALL_ROLE)) {
      this.toggleAll(event.target.checked)
    } else if (event.target.matches(RESOURCE_ROLE)) {
      const checkAll = this.element.querySelector(ALL_ROLE)
      if (checkAll) checkAll.checked = false
      this.syncButton()
    }
  }

  onClick(event) {
    const link = event.target.closest(LINK_SELECTOR)
    if (!link || !this.element.contains(link)) return
    event.preventDefault()
    // The legacy effective_datatables bulk_actions script (loaded on the page)
    // also delegates clicks on .buttons-bulk-actions a; stop the event here so
    // only this controller posts, avoiding a duplicate request.
    event.stopPropagation()
    const group = link.closest(".buttons-bulk-actions")
    if (group) group.classList.remove("open")
    this.submit(link)
  }

  // Disable ineligible row checkboxes and sync the dropdown button on the initial
  // render and after each redraw.
  refresh() {
    this.resources().forEach((checkbox) => {
      if (checkbox.dataset.status === "Ineligible") {
        checkbox.disabled = true
        checkbox.classList.add("disabled")
      }
    })
    this.syncButton()
  }

  toggleAll(checked) {
    this.resources().forEach((checkbox) => {
      if (checkbox.dataset.status === "Eligible") checkbox.checked = checked
    })
    this.syncButton()
  }

  syncButton() {
    const anyChecked = this.resources().some((checkbox) => checkbox.checked)
    this.element.querySelectorAll(".buttons-bulk-actions button").forEach((button) => {
      button.disabled = !anyChecked
    })
  }

  submit(link) {
    const url = link.getAttribute("href")
    const ids = this.resources().filter((checkbox) => checkbox.checked).map((checkbox) => checkbox.value)
    if (!url || ids.length === 0) return

    const confirmation = link.dataset.confirm
    if (confirmation && !window.confirm(confirmation)) return

    const title = link.textContent.trim()
    const button = link.closest(".buttons-bulk-actions").querySelector("button")
    if (button) button.disabled = true
    this.showMessage("Processing...")

    axios({
      method: "POST",
      url: url,
      data: { ids: ids },
      // generate_invoice only responds to format.js; an Accept of */* lets Rails
      // serve it (and binder_paid's explicit JSON render) without a 406.
      headers: { "X-CSRF-Token": this.csrfToken(), "Accept": "*/*" }
    })
      .then((response) => this.showMessage((response.data && response.data.message) || `Successfully completed ${title} bulk action`))
      .catch((error) => {
        const message = (error.response && error.response.data && error.response.data.message) ||
          `An error occured while attempting ${title} bulk action`
        this.showMessage(message)
        window.alert(message)
      })
      // Hold the result message briefly, then redraw so refreshed row data
      // (e.g. the Invoiced? column) is reflected.
      .finally(() => setTimeout(() => this.requestRedraw(), MESSAGE_VISIBLE_MS))
  }

  requestRedraw() {
    const datatable = this.application.getControllerForElementAndIdentifier(this.element, "datatable")
    if (datatable) datatable.redraw()
  }

  resources() {
    return Array.from(this.element.querySelectorAll(RESOURCE_ROLE))
  }

  showMessage(message) {
    const processing = this.element.querySelector(".dataTables_processing")
    if (!processing) return
    processing.innerHTML = message
    processing.style.display = "block"
  }

  csrfToken() {
    const meta = document.querySelector("meta[name=csrf-token]")
    return meta ? meta.content : ""
  }
}
