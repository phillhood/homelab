<script setup lang="ts">
defineProps<{
  muted?: boolean
}>()
</script>

<template>
  <div class="card-icon" :class="{ 'card-icon--muted': muted }">
    <slot />
  </div>
</template>

<style scoped>
.card-icon {
  width: 48px;
  height: 48px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, var(--purple-deep), var(--cyan-dim));
  border-radius: var(--radius-md);
  position: relative;
}

.card-icon::before {
  content: '';
  position: absolute;
  inset: -8px;
  background: inherit;
  border-radius: var(--radius-lg);
  filter: blur(16px);
  opacity: 0.4;
  z-index: -1;
}

.card-icon--muted {
  background: linear-gradient(135deg, rgba(124, 58, 237, 0.5), rgba(8, 145, 178, 0.5));
}

.card-icon :deep(svg) {
  width: 24px;
  height: 24px;
  stroke: var(--text-primary);
  stroke-width: 1.5;
  fill: none;
}
</style>
