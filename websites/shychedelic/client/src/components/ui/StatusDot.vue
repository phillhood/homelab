<script setup lang="ts">
import type { ServerStatus } from '@/types'

withDefaults(defineProps<{
  status?: ServerStatus
}>(), {
  status: 'offline'
})
</script>

<template>
  <span class="status-dot" :class="`status-dot--${status}`" />
</template>

<style scoped>
.status-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: var(--text-muted);
  flex-shrink: 0;
}

.status-dot--online {
  background: var(--status-online);
  box-shadow: 0 0 8px var(--status-online);
  animation: status-pulse 2s ease-in-out infinite;
}

.status-dot--offline {
  background: var(--status-offline);
}

.status-dot--pending {
  background: var(--status-pending);
}
</style>
