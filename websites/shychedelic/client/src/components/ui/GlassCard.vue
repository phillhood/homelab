<script setup lang="ts">
defineProps<{
  featured?: boolean
  muted?: boolean
}>()

function onMouseMove(e: MouseEvent): void {
  const target = e.currentTarget as HTMLElement
  const rect = target.getBoundingClientRect()
  const x = ((e.clientX - rect.left) / rect.width) * 100
  const y = ((e.clientY - rect.top) / rect.height) * 100
  target.style.setProperty('--mouse-x', `${x}%`)
  target.style.setProperty('--mouse-y', `${y}%`)
}
</script>

<template>
  <article
    class="glass-card"
    :class="{ 'glass-card--featured': featured, 'glass-card--muted': muted }"
    @mousemove="onMouseMove"
  >
    <slot />
  </article>
</template>

<style scoped>
.glass-card {
  position: relative;
  padding: 1.75rem;
  background: var(--glass-bg);
  border: 1px solid var(--glass-border);
  border-radius: var(--radius-lg);
  backdrop-filter: blur(8px);
  -webkit-backdrop-filter: blur(8px);
  transition: all var(--transition-smooth);
  overflow: hidden;
}

.glass-card::before {
  content: '';
  position: absolute;
  inset: 0;
  border-radius: var(--radius-lg);
  padding: 1px;
  background: linear-gradient(135deg, var(--glass-highlight), transparent 50%, transparent);
  -webkit-mask: linear-gradient(#fff 0 0) content-box, linear-gradient(#fff 0 0);
  mask: linear-gradient(#fff 0 0) content-box, linear-gradient(#fff 0 0);
  -webkit-mask-composite: xor;
  mask-composite: exclude;
  pointer-events: none;
}

.glass-card::after {
  content: '';
  position: absolute;
  inset: -50%;
  background: radial-gradient(circle at var(--mouse-x, 50%) var(--mouse-y, 50%), var(--purple-deep) 0%, transparent 50%);
  opacity: 0;
  transition: opacity var(--transition-smooth);
  pointer-events: none;
  z-index: -1;
}

.glass-card:hover {
  border-color: rgba(124, 58, 237, 0.3);
  transform: translateY(-4px);
  box-shadow:
    0 20px 40px rgba(0, 0, 0, 0.3),
    0 0 60px rgba(124, 58, 237, 0.1);
}

.glass-card:hover::after {
  opacity: 0.15;
}

.glass-card--featured {
  width: 100%;
}

.glass-card--muted :deep(*) {
  opacity: 0.7;
}

.glass-card--muted:hover :deep(*) {
  opacity: 0.85;
}

@media (max-width: 640px) {
  .glass-card {
    padding: 1.5rem;
  }
}
</style>
