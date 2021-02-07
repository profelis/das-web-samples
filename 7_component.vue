<template>
  <p class="hello">Status: {{ status }}</p>
</template>

<script>
module.exports = {
  props: ["status"],
};
</script>

<style>
.hello {
  background-color: #e44;
}
</style>