import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    window.addEventListener('scroll', this.updateNavbar)
  }

  disconnect() {
    window.removeEventListener('scroll', this.updateNavbar)
  }

  updateNavbar = () => {
    if (window.scrollY > 50) {
      this.element.classList.add('scrolled')
    } else {
      this.element.classList.remove('scrolled')
    }
  }
}
