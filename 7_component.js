Vue.component('my-component', {
  props: ['status'],
  template: `
    <p style="background-color: #e44">Status: {{ status }}</p>
  `
})