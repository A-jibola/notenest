import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  toggleMenu() {
    const menu = document.getElementById("mobile-menu-toggle")
    if (menu) {
      menu.classList.toggle("hidden")
    }
  }
}
