<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useApi } from '@/composables/useApi'
import { useAuthStore } from '@/stores/auth'

const router = useRouter()
const route = useRoute()
const authStore = useAuthStore()
const api = useApi()
const errorMessage = ref<string | null>(null)

onMounted(async () => {
  const token = route.query.token as string | undefined
  const type = route.query.type as string | undefined

  if (type === 'verify-email' && token) {
    try {
      await api.verifyEmail(token)
      authStore.openModal('login')
    } catch {
      errorMessage.value = 'Failed to verify email'
    }
    setTimeout(() => router.replace('/'), 2000)
    return
  }

  if (type === 'reset-password' && token) {
    router.replace({ path: '/auth/reset-password', query: { token } })
    return
  }

  const errorParam = route.query.error as string | undefined
  if (errorParam) {
    errorMessage.value = route.query.error_description as string || 'Authentication failed'
    setTimeout(() => router.replace('/'), 3000)
    return
  }

  router.replace('/')
})
</script>

<template>
  <div class="callback-page">
    <div v-if="errorMessage" class="error-state">
      <p class="error-text">{{ errorMessage }}</p>
      <p class="redirect-text">Redirecting...</p>
    </div>
    <div v-else class="loading">
      <div class="spinner" />
      <p>Processing...</p>
    </div>
  </div>
</template>

<style scoped>
.callback-page {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
}

.loading {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 1rem;
}

.spinner {
  width: 40px;
  height: 40px;
  border: 3px solid rgba(255, 255, 255, 0.1);
  border-top-color: var(--purple-bright);
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

.loading p {
  color: var(--text-secondary);
  font-size: 0.9rem;
}

.error-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.5rem;
  text-align: center;
}

.error-text {
  color: rgba(248, 113, 113, 0.9);
  font-size: 0.95rem;
}

.redirect-text {
  color: var(--text-muted);
  font-size: 0.85rem;
}
</style>
