import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    window.addEventListener('scroll', this.updateNavbar)
  }

  disconnect() {
    window.removeEventListener('scroll', this.updateNavbar)
  }

  updateNavbar = () => {
    if (window.scrollY >= 100) {
      this.element.classList.add("navbar-knowsomenow-white")
    } else {
      this.element.classList.remove("navbar-knowsomenow-white")
    }
  }
}
