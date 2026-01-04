import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "backdrop"]

  connect() {
    // Check if modal has already been shown in this session
    if (!sessionStorage.getItem('notenest_welcome_shown')) {
      this.showModal()
    } else {
      this.hideModal()
    }
  }

  showModal() {
    this.modalTarget.classList.remove('hidden')
    this.backdropTarget.classList.remove('hidden')
    // Prevent body scroll when modal is open
    document.body.style.overflow = 'hidden'
  }

  hideModal() {
    this.modalTarget.classList.add('hidden')
    this.backdropTarget.classList.add('hidden')
    // Restore body scroll
    document.body.style.overflow = ''
  }

  dismiss() {
    // Set sessionStorage to remember modal was shown
    sessionStorage.setItem('notenest_welcome_shown', 'true')
    this.hideModal()
  }
}

