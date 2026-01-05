import { Application } from "@hotwired/stimulus"

const application = Application.start()

// Configure Stimulus development experience
application.debug = false
window.Stimulus   = application


document.addEventListener('DOMContentLoaded', () => {
  const bell = document.getElementById('notification-bell');
  const dropdown = document.getElementById('notification-dropdown');

  // Only add event listener if both elements exist
  if (bell && dropdown) {
    document.addEventListener('click', (e) => {
      if (!dropdown.contains(e.target) && !bell.contains(e.target)) {
        dropdown.classList.add('hidden');
      }
    });
  }

});


export { application }
