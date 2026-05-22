import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["output"]
  
  sendVal() {
    return this.outputTarget.value
  }
}