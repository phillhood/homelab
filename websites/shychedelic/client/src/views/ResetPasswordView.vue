<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useApi } from '@/composables/useApi'

const router = useRouter()
const route = useRoute()
const api = useApi()

const token = ref('')
const newPassword = ref('')
const confirmPassword = ref('')
const isLoading = ref(false)
const error = ref<string | null>(null)
const success = ref(false)

const canSubmit = computed(() =>
  newPassword.value.length >= 8 &&
  newPassword.value === confirmPassword.value &&
  !isLoading.value
)

onMounted(() => {
  token.value = (route.query.token as string) || ''
  if (!token.value) {
    router.replace('/')
  }
})

async function handleSubmit(): Promise<void> {
  if (!canSubmit.value) return

  isLoading.value = true
  error.value = null

  try {
    await api.resetPassword(token.value, newPassword.value)
    success.value = true
    setTimeout(() => router.replace('/'), 3000)
  } catch (err) {
    error.value = err instanceof Error ? err.message : 'Reset failed'
  } finally {
    isLoading.value = false
  }
}
</script>

<template>
  <div class="reset-page">
    <div class="reset-card">
      <div v-if="success" class="success-state">
        <h2>Password Reset</h2>
        <p>Your password has been updated. Redirecting...</p>
      </div>
      <form v-else @submit.prevent="handleSubmit" class="reset-form">
        <h2>Set New Password</h2>

        <input
          v-model="newPassword"
          type="password"
          class="auth-input"
          placeholder="New password"
          autocomplete="new-password"
        />

        <input
          v-model="confirmPassword"
          type="password"
          class="auth-input"
          :class="{ 'input-error': confirmPassword && newPassword !== confirmPassword }"
          placeholder="Confirm password"
          autocomplete="new-password"
        />

        <p v-if="error" class="error-text">{{ error }}</p>

        <button type="submit" class="auth-button" :disabled="!canSubmit">
          {{ isLoading ? 'Resetting...' : 'Reset Password' }}
        </button>
      </form>
    </div>
  </div>
</template>

<style scoped>
.reset-page {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 1.5rem;
}

.reset-card {
  width: 100%;
  max-width: 400px;
  padding: 2.5rem 2rem;
  background: linear-gradient(165deg, rgba(24, 24, 36, 0.98) 0%, rgba(14, 14, 22, 0.98) 100%);
  border: 1px solid var(--glass-border);
  border-radius: var(--radius-lg);
}

.reset-form {
  display: flex;
  flex-direction: column;
  gap: 1.25rem;
}

h2 {
  font-size: 1.25rem;
  font-weight: 600;
  text-align: center;
  margin-bottom: 0.5rem;
}

.auth-input {
  width: 100%;
  padding: 0.875rem 1rem;
  background: rgba(255, 255, 255, 0.05);
  border: 1px solid var(--glass-border);
  border-radius: var(--radius-sm);
  color: var(--text-primary);
  font-size: 0.95rem;
  font-family: inherit;
  transition: all var(--transition-base);
}

.auth-input:focus {
  outline: none;
  border-color: var(--purple-bright);
  box-shadow: 0 0 0 3px rgba(168, 85, 247, 0.15);
}

.auth-input::placeholder {
  color: var(--text-muted);
}

.auth-input.input-error {
  border-color: rgba(239, 68, 68, 0.5);
}

.error-text {
  color: rgba(248, 113, 113, 0.9);
  font-size: 0.85rem;
  text-align: center;
}

.auth-button {
  width: 100%;
  padding: 0.875rem 1.25rem;
  background: linear-gradient(135deg, var(--purple-deep) 0%, var(--cyan-dim) 100%);
  border: none;
  border-radius: var(--radius-sm);
  color: white;
  font-family: 'Sora', sans-serif;
  font-size: 0.95rem;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.25s ease;
}

.auth-button:hover:not(:disabled) {
  transform: translateY(-2px);
}

.auth-button:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.success-state {
  text-align: center;
}

.success-state p {
  color: var(--text-secondary);
  margin-top: 0.75rem;
}
</style>
