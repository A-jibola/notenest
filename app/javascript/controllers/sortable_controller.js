import { Controller } from '@hotwired/stimulus'
import Sortable from 'sortablejs'

export default class extends Controller{
    static targets = ["list"]

    connect(){
        this.sortable = Sortable.create(this.element, {
            handle: ".handle",
            animation: 150,
            onEnd: this.reOrder.bind(this)
        })
    }

    reOrder(){
        const items = this.element.querySelectorAll("[data-step-id]")

        items.forEach((item, index) => {
            const orderInput = item.querySelector("input[name*='[order]']")
            if (orderInput){
                orderInput.value = index + 1
            }
        });
    }
}