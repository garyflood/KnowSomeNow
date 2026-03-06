// app/javascript/controllers/quick_add_controller.js
//
// QuickAdd controller — wires the popular-devices marquee to the
// "Add New Device" form so clicking a device card pre-fills the
// name input and submits the form automatically.
//
// Targets:
//   nameInput  — the <input> for device[name]
//   form       — the <form> element to submit
//
// Usage on a card:
//   data-action="click->quick-add#fill"
//   data-quick-add-name-param="iPhone"

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["nameInput", "form"]

  // Silently set the device name and submit — user never sees the input fill
  fill({ params: { name } }) {
    // Set the device name from the clicked card's data-quick-add-name-param
    this.nameInputTarget.value = name

    // Submit via requestSubmit() so Turbo and validation hooks fire correctly
    this.formTarget.requestSubmit()
  }
}
