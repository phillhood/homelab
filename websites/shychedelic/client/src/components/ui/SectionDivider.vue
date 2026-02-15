<script setup lang="ts">
defineProps<{
  label?: string
}>()
</script>

<template>
  <div class="section-divider">
    <div class="divider-line" />
    <span v-if="label" class="divider-text">{{ label }}</span>
    <div class="divider-line" />
  </div>
</template>

<style scoped>
.section-divider {
  display: flex;
  align-items: center;
  gap: 1.5rem;
  margin: 2.5rem 0;
}

.divider-line {
  flex: 1;
  height: 1px;
  background: linear-gradient(90deg, transparent, var(--glass-border), transparent);
}

.divider-text {
  font-family: 'Sora', sans-serif;
  font-size: 0.7rem;
  font-weight: 500;
  letter-spacing: 0.25em;
  text-transform: uppercase;
  color: var(--text-muted);
}
</style>
