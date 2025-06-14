import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="steps"
export default class extends Controller {
  connect() {
  }

  add(event){
    event.preventDefault()

    const template = document.getElementById("step-template");
    const clone = template.content.cloneNode(true);

    // Replace the placeholder with a unique identifier
    const newId = new Date().getTime();
    const html = clone.firstElementChild.innerHTML.replace(/NEW_RECORD/g, newId);

    // Create a new div and set its innerHTML
    const div = document.createElement("div");
    div.classList = "step-fields handle";
    div.setAttribute('data-step-id', newId);
    div.innerHTML = html;

    // Append the new step to the steps container
    document.getElementById("steps").appendChild(div);
    }

}
