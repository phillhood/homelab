<script setup lang="ts">
import { computed, type Component } from 'vue'
import { RouterLink } from 'vue-router'

interface Props {
  to?: string
  href?: string
  variant?: 'primary' | 'secondary'
}

const props = withDefaults(defineProps<Props>(), {
  variant: 'primary'
})

const component = computed<Component | string>(() => {
  if (props.to) return RouterLink
  if (props.href) return 'a'
  return 'button'
})

const linkProps = computed(() => {
  if (props.to) return { to: props.to }
  if (props.href) return { href: props.href, target: '_blank', rel: 'noopener' }
  return {}
})
</script>

<template>
  <component
    :is="component"
    v-bind="linkProps"
    class="app-button"
    :class="`app-button--${variant}`"
  >
    <slot />
    <svg class="app-button__arrow" viewBox="0 0 24 24">
      <path d="M5 12h14M12 5l7 7-7 7" />
    </svg>
  </component>
</template>

<style scoped>
.app-button {
  position: relative;
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  margin-top: 1rem;
  padding: 0.625rem 1.125rem;
  font-family: 'Sora', sans-serif;
  font-size: 0.8rem;
  font-weight: 500;
  color: var(--text-primary);
  background: linear-gradient(
    135deg,
    rgba(124, 58, 237, 0.12) 0%,
    rgba(6, 182, 212, 0.08) 100%
  );
  border: none;
  border-radius: var(--radius-sm);
  cursor: pointer;
  transition: all 0.25s cubic-bezier(0.34, 1.3, 0.64, 1);
  overflow: hidden;
  text-decoration: none;
}

.app-button::before {
  content: '';
  position: absolute;
  inset: 0;
  border-radius: inherit;
  padding: 1px;
  background: linear-gradient(
    135deg,
    rgba(168, 85, 247, 0.5) 0%,
    rgba(6, 182, 212, 0.3) 100%
  );
  -webkit-mask: linear-gradient(#fff 0 0) content-box, linear-gradient(#fff 0 0);
  mask: linear-gradient(#fff 0 0) content-box, linear-gradient(#fff 0 0);
  -webkit-mask-composite: xor;
  mask-composite: exclude;
  pointer-events: none;
  transition: opacity 0.25s ease;
}

.app-button::after {
  content: '';
  position: absolute;
  inset: -4px;
  background: linear-gradient(135deg, var(--purple-deep), var(--cyan-dim));
  border-radius: calc(var(--radius-sm) + 4px);
  filter: blur(12px);
  opacity: 0;
  z-index: -1;
  transition: opacity 0.25s ease;
}

.app-button:hover {
  transform: translateY(-2px);
  background: linear-gradient(
    135deg,
    rgba(124, 58, 237, 0.2) 0%,
    rgba(6, 182, 212, 0.12) 100%
  );
}

.app-button:hover::before {
  background: linear-gradient(
    135deg,
    rgba(168, 85, 247, 0.7) 0%,
    rgba(6, 182, 212, 0.5) 100%
  );
}

.app-button:hover::after {
  opacity: 0.35;
}

.app-button:active {
  transform: translateY(0);
}

.app-button__arrow {
  width: 14px;
  height: 14px;
  stroke: currentColor;
  stroke-width: 2;
  fill: none;
  transition: transform 0.25s cubic-bezier(0.34, 1.3, 0.64, 1);
}

.app-button:hover .app-button__arrow {
  transform: translateX(3px);
}

.app-button--secondary {
  background: rgba(255, 255, 255, 0.03);
}

.app-button--secondary::before {
  background: linear-gradient(
    135deg,
    rgba(255, 255, 255, 0.15) 0%,
    rgba(255, 255, 255, 0.05) 100%
  );
}

.app-button--secondary::after {
  display: none;
}

.app-button--secondary:hover {
  background: rgba(255, 255, 255, 0.06);
}

.app-button--secondary:hover::before {
  background: linear-gradient(
    135deg,
    rgba(255, 255, 255, 0.25) 0%,
    rgba(255, 255, 255, 0.1) 100%
  );
}
</style>
