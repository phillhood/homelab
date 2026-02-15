import { createApp, type DirectiveBinding } from 'vue'
import { createPinia } from 'pinia'
import router from './router'
import App from './App.vue'

import './assets/styles/theme.css'
import './assets/styles/animations.css'

interface ClickOutsideElement extends HTMLElement {
  _clickOutside?: (event: Event) => void
}

const app = createApp(App)

app.directive('click-outside', {
  mounted(el: ClickOutsideElement, binding: DirectiveBinding<(event: Event) => void>) {
    el._clickOutside = (event: Event) => {
      if (!(el === event.target || el.contains(event.target as Node))) {
        binding.value(event)
      }
    }
    document.addEventListener('click', el._clickOutside)
  },
  unmounted(el: ClickOutsideElement) {
    if (el._clickOutside) {
      document.removeEventListener('click', el._clickOutside)
    }
  }
})

app.use(createPinia())
app.use(router)

app.mount('#app')
