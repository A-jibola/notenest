import { Controller } from "@hotwired/stimulus"

export default class extends Controller {

    static targets = ["bell"]

    connect(){
        const dropdown = document.getElementById('notification-dropdown');
        const bell = document.getElementById('notification-bell');
        
        // Check if elements exist before adding event listeners
        if (!dropdown || !bell) {
            return;
        }
        
        this.bellTarget.addEventListener('click', () => {
            dropdown.classList.toggle('hidden');
        });

        document.addEventListener('click', (e) => {
            if (!dropdown.contains(e.target) && !bell.contains(e.target)) {
                dropdown.classList.add('hidden');
            }
        })

    }
    

}
