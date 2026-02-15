<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import HeroSection from '@/components/layout/HeroSection.vue'
import GlassCard from '@/components/ui/GlassCard.vue'
import CardIcon from '@/components/ui/CardIcon.vue'
import AppButton from '@/components/ui/AppButton.vue'
import MatrixIcon from '@/assets/icons/matrix.svg'
import { useAuthStore } from '@/stores/auth'
import { useApi } from '@/composables/useApi'

const router = useRouter()
const authStore = useAuthStore()
const api = useApi()

const matrixServer = 'matrix.shychedelic.com'
const matrixRoom = '#general:shychedelic.com'

const isJoining = ref(false)
const joinError = ref<string | null>(null)

onMounted(() => {
  if (!authStore.isAuthenticated) {
    router.replace('/')
  }
})

async function joinChat(): Promise<void> {
  isJoining.value = true
  joinError.value = null

  try {
    const { elementUrl } = await api.getMatrixLoginToken()
    window.location.href = elementUrl
  } catch (err) {
    joinError.value = err instanceof Error ? err.message : 'Failed to join chat'
  } finally {
    isJoining.value = false
  }
}
</script>

<template>
  <div v-if="authStore.isAuthenticated" class="page">
    <HeroSection title="Matrix" tagline="Secure Chat" :icon="MatrixIcon" />

    <section class="matrix-section">
    <div class="matrix-container">
      <GlassCard featured>
        <CardIcon class="matrix-icon">
          <svg viewBox="0 0 24 24">
            <path d="M21 15a2 2 0 01-2 2H7l-4 4V5a2 2 0 012-2h14a2 2 0 012 2v10z"/>
          </svg>
        </CardIcon>

        <div class="info-grid">
          <div class="info-item">
            <span class="info-label">Server</span>
            <code class="info-value">{{ matrixServer }}</code>
          </div>
          <div class="info-item">
            <span class="info-label">Main Room</span>
            <code class="info-value">{{ matrixRoom }}</code>
          </div>
        </div>

        <div class="button-row">
          <AppButton @click="joinChat" :disabled="isJoining">
            {{ isJoining ? 'Connecting...' : 'Join Chat' }}
          </AppButton>
          <AppButton :href="`https://matrix.to/#/${matrixRoom}`">
            Open in Element
          </AppButton>
        </div>

        <p v-if="joinError" class="join-error">{{ joinError }}</p>
      </GlassCard>

      <div class="clients-section">
        <h3 class="section-title">Recommended Clients</h3>
        <div class="clients-grid">
          <GlassCard>
            <h4 class="client-name">Element</h4>
            <p class="client-desc">Official client, full-featured</p>
            <div class="features">
              <span class="feature" title="Voice & video calls">
                <svg viewBox="0 0 24 24"><path d="M15.05 5A5 5 0 0119 8.95M15.05 1A9 9 0 0123 8.94M22 16.92v3a2 2 0 01-2.18 2 19.79 19.79 0 01-8.63-3.07 19.5 19.5 0 01-6-6 19.79 19.79 0 01-3.07-8.67A2 2 0 014.11 2h3a2 2 0 012 1.72c.127.96.361 1.903.7 2.81a2 2 0 01-.45 2.11L8.09 9.91a16 16 0 006 6l1.27-1.27a2 2 0 012.11-.45c.907.339 1.85.573 2.81.7A2 2 0 0122 16.92z"/></svg>
                Voice
              </span>
              <span class="feature" title="Desktop, mobile, and web">
                <svg viewBox="0 0 24 24"><rect x="2" y="3" width="20" height="14" rx="2"/><path d="M8 21h8M12 17v4"/></svg>
                All platforms
              </span>
              <span class="feature" title="End-to-end encryption">
                <svg viewBox="0 0 24 24"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0110 0v4"/></svg>
                E2EE
              </span>
            </div>
            <AppButton href="https://element.io/download">Try Element</AppButton>
          </GlassCard>

          <GlassCard>
            <h4 class="client-name">Cinny</h4>
            <p class="client-desc">Discord-like UI, lightweight</p>
            <div class="features">
              <span class="feature feature--disabled" title="No voice support">
                <svg viewBox="0 0 24 24"><path d="M15.05 5A5 5 0 0119 8.95M15.05 1A9 9 0 0123 8.94M22 16.92v3a2 2 0 01-2.18 2 19.79 19.79 0 01-8.63-3.07 19.5 19.5 0 01-6-6 19.79 19.79 0 01-3.07-8.67A2 2 0 014.11 2h3a2 2 0 012 1.72c.127.96.361 1.903.7 2.81a2 2 0 01-.45 2.11L8.09 9.91a16 16 0 006 6l1.27-1.27a2 2 0 012.11-.45c.907.339 1.85.573 2.81.7A2 2 0 0122 16.92z"/><line x1="1" y1="1" x2="23" y2="23"/></svg>
                No voice
              </span>
              <span class="feature" title="Web and desktop">
                <svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="10"/><path d="M2 12h20M12 2a15.3 15.3 0 014 10 15.3 15.3 0 01-4 10 15.3 15.3 0 01-4-10 15.3 15.3 0 014-10z"/></svg>
                Web
              </span>
              <span class="feature" title="End-to-end encryption">
                <svg viewBox="0 0 24 24"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0110 0v4"/></svg>
                E2EE
              </span>
            </div>
            <AppButton href="https://cinny.in">Try Cinny</AppButton>
          </GlassCard>
        </div>
      </div>
    </div>
  </section>
  </div>
</template>

<style scoped>
.matrix-section {
  padding: 2rem;
  padding-bottom: 4rem;
}

.matrix-container {
  max-width: 680px;
  margin: 0 auto;
}

.matrix-icon {
  margin-bottom: 1.25rem;
}

.info-grid {
  display: grid;
  gap: 1rem;
  margin-bottom: 1.5rem;
}

.info-item {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.info-label {
  font-size: 0.75rem;
  font-weight: 500;
  color: var(--text-muted);
  text-transform: uppercase;
  letter-spacing: 0.1em;
}

.info-value {
  font-family: 'DM Sans', monospace;
  font-size: 0.9rem;
  color: var(--cyan);
  background: rgba(6, 182, 212, 0.1);
  padding: 0.5rem 0.75rem;
  border-radius: var(--radius-sm);
  border: 1px solid rgba(6, 182, 212, 0.2);
}

.button-row {
  display: flex;
  flex-wrap: wrap;
  gap: 0.75rem;
}

.join-error {
  margin-top: 0.5rem;
  font-size: 0.85rem;
  color: rgba(248, 113, 113, 0.9);
}

.clients-section {
  margin-top: 3rem;
}

.section-title {
  font-size: 0.8rem;
  font-weight: 500;
  color: var(--text-muted);
  text-transform: uppercase;
  letter-spacing: 0.15em;
  margin-bottom: 1.25rem;
  text-align: center;
}

.clients-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 1rem;
}

.client-name {
  font-size: 1rem;
  font-weight: 600;
  margin-bottom: 0.25rem;
}

.client-desc {
  font-size: 0.85rem;
  color: var(--text-secondary);
  margin-bottom: 0.75rem;
}

.features {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  margin-bottom: 0.5rem;
}

.feature {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  padding: 0.3rem 0.6rem;
  font-size: 0.7rem;
  color: var(--text-secondary);
  background: rgba(255, 255, 255, 0.05);
  border-radius: 4px;
}

.feature svg {
  width: 12px;
  height: 12px;
  stroke: currentColor;
  stroke-width: 2;
  fill: none;
}

.feature--disabled {
  color: var(--text-muted);
  text-decoration: line-through;
}

@media (max-width: 640px) {
  .clients-grid {
    grid-template-columns: 1fr;
  }
}
</style>
