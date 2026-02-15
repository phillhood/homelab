<script setup lang="ts">
import { onMounted } from 'vue'
import HeroSection from '@/components/layout/HeroSection.vue'
import GlassCard from '@/components/ui/GlassCard.vue'
import CardIcon from '@/components/ui/CardIcon.vue'
import StatusDot from '@/components/ui/StatusDot.vue'
import { useServerStatus } from '@/composables/useServerStatus'

const { servers, loading, overallStatus, statusText, refresh } = useServerStatus()

onMounted(() => {
  refresh()
})
</script>

<template>
  <div class="page">
    <HeroSection title="Game Servers" tagline="Connection Info" />

    <section class="servers-section">
    <div class="servers-container">
      <div class="status-banner">
        <StatusDot :status="overallStatus === 'partial' ? 'pending' : overallStatus" />
        <span>{{ statusText }}</span>
      </div>

      <div v-if="loading" class="loading-state">
        Loading servers...
      </div>

      <div v-else-if="servers.length === 0" class="empty-state">
        <p>No servers configured yet.</p>
      </div>

      <div v-else class="servers-grid">
        <GlassCard v-for="server in servers" :key="server.id">
          <CardIcon>
            <svg viewBox="0 0 24 24">
              <rect x="2" y="3" width="20" height="14" rx="2"/>
              <path d="M8 21h8M12 17v4"/>
            </svg>
          </CardIcon>
          <h2 class="card-title">{{ server.name }}</h2>
          <p class="server-address">{{ server.address }}</p>
          <div class="status-row">
            <StatusDot :status="server.status" />
            <span>{{ server.status === 'online' ? 'Online' : 'Offline' }}</span>
            <span v-if="server.players" class="player-count">
              {{ server.players.online }}/{{ server.players.max }} players
            </span>
          </div>
        </GlassCard>
      </div>
    </div>
  </section>
  </div>
</template>

<style scoped>
.servers-section {
  padding: 2rem;
  padding-bottom: 4rem;
}

.servers-container {
  max-width: 800px;
  margin: 0 auto;
}

.status-banner {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.75rem;
  padding: 1rem;
  margin-bottom: 2rem;
  background: var(--glass-bg);
  border: 1px solid var(--glass-border);
  border-radius: var(--radius-md);
  font-size: 0.9rem;
  color: var(--text-secondary);
}

.servers-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
  gap: 1.5rem;
}

.card-title {
  font-size: 1.125rem;
  font-weight: 600;
  margin-bottom: 0.25rem;
}

.server-address {
  font-family: 'DM Sans', monospace;
  font-size: 0.85rem;
  color: var(--cyan);
  margin-bottom: 1rem;
}

.status-row {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.8rem;
  color: var(--text-muted);
}

.player-count {
  margin-left: auto;
  color: var(--text-secondary);
}

.loading-state,
.empty-state {
  text-align: center;
  padding: 3rem;
  color: var(--text-muted);
}
</style>
