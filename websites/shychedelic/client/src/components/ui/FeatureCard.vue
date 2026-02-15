<script setup lang="ts">
import { computed } from 'vue'
import { useAuthStore } from '@/stores/auth'
import GlassCard from './GlassCard.vue'
import CardIcon from './CardIcon.vue'
import StatusDot from './StatusDot.vue'

const props = withDefaults(defineProps<{
  title: string
  description?: string
  status?: 'online' | 'offline' | 'pending' | 'coming-soon'
  statusText?: string
  featured?: boolean
  requiresAuth?: boolean
}>(), {
  status: 'online',
  featured: false,
  requiresAuth: true
})

const authStore = useAuthStore()

const isLocked = computed(() => props.requiresAuth && !authStore.isAuthenticated)
const isMuted = computed(() => props.status === 'coming-soon' || props.status === 'offline')
</script>

<template>
  <GlassCard :featured="featured" :muted="isMuted">
    <div class="card-header">
      <CardIcon :muted="isMuted" class="card-header-icon">
        <slot name="icon" />
      </CardIcon>
      <div class="card-header-content">
        <h2 class="card-title">{{ title }}</h2>
        <div class="status-row">
          <StatusDot :status="status === 'coming-soon' ? 'pending' : status" />
          <span>{{ status === 'online' ? 'Available' : statusText }}</span>
        </div>
      </div>
    </div>

    <p v-if="description" class="card-description">{{ description }}</p>

    <div v-if="status === 'online' && !isLocked" class="card-actions">
      <slot name="action" />
    </div>

    <p v-if="status === 'online' && isLocked" class="login-hint">
      <svg viewBox="0 0 24 24" class="login-hint-icon">
        <rect x="3" y="11" width="18" height="11" rx="2" ry="2" />
        <path d="M7 11V7a5 5 0 0110 0v4" />
      </svg>
      Sign in for access
    </p>
  </GlassCard>
</template>

<style scoped>
.card-header {
  display: flex;
  align-items: center;
  gap: 1rem;
}

.card-header-icon {
  flex-shrink: 0;
}

.card-header-content {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
  min-width: 0;
}

.card-title {
  font-family: 'Sora', sans-serif;
  font-size: 1.125rem;
  font-weight: 600;
  color: var(--text-primary);
  line-height: 1.2;
}

.status-row {
  display: flex;
  align-items: center;
  gap: 0.375rem;
  font-size: 0.75rem;
  color: var(--text-muted);
}

.card-description {
  margin-top: 1rem;
  font-size: 0.9rem;
  color: var(--text-secondary);
  line-height: 1.6;
}

.card-actions {
  margin-top: 0.25rem;
}

.login-hint {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin-top: 1rem;
  font-size: 0.8rem;
  color: var(--text-muted);
}

.login-hint-icon {
  width: 14px;
  height: 14px;
  stroke: currentColor;
  stroke-width: 1.5;
  stroke-linecap: round;
  stroke-linejoin: round;
  fill: none;
}
</style>
