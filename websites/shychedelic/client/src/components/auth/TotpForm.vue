<script setup lang="ts">
import { ref, watch } from 'vue'
import { useAuthStore } from '@/stores/auth'

const authStore = useAuthStore()

const code = ref('')
const inputRef = ref<HTMLInputElement | null>(null)

watch(code, (val) => {
  const cleaned = val.replace(/\D/g, '').slice(0, 6)
  if (cleaned !== val) {
    code.value = cleaned
  }
  if (cleaned.length === 6) {
    handleSubmit()
  }
})

function handleSubmit(): void {
  if (code.value.length !== 6) return
  authStore.verifyTotp(code.value)
}

defineExpose({
  focus: () => inputRef.value?.focus()
})
</script>

<template>
  <form @submit.prevent="handleSubmit" class="stage">
    <div class="stage-header">
      <div class="mfa-icon">
        <svg viewBox="0 0 24 24">
          <rect x="3" y="11" width="18" height="11" rx="2" ry="2" />
          <path d="M7 11V7a5 5 0 0110 0v4" />
        </svg>
      </div>
      <h3 class="stage-title">Two-factor authentication</h3>
      <p class="stage-subtitle">Enter the 6-digit code from your authenticator app</p>
    </div>

    <div class="input-group">
      <input
        ref="inputRef"
        v-model="code"
        type="text"
        inputmode="numeric"
        class="auth-input code-input"
        placeholder="000000"
        autocomplete="one-time-code"
        maxlength="6"
        autofocus
      />
    </div>

    <button type="submit" class="auth-button" :disabled="code.length !== 6 || authStore.isLoading">
      {{ authStore.isLoading ? 'Verifying...' : 'Verify' }}
    </button>
  </form>
</template>

<style scoped>
.stage {
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
}

.stage-header {
  text-align: center;
}

.mfa-icon {
  width: 48px;
  height: 48px;
  margin: 0 auto 1rem;
  padding: 0.75rem;
  background: rgba(124, 58, 237, 0.15);
  border-radius: var(--radius-md);
}

.mfa-icon svg {
  width: 100%;
  height: 100%;
  stroke: var(--purple-bright);
  stroke-width: 2;
  fill: none;
}

.stage-title {
  font-size: 1.25rem;
  font-weight: 600;
  margin-bottom: 0.5rem;
}

.stage-subtitle {
  font-size: 0.9rem;
  color: var(--text-secondary);
}

.input-group {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
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

.code-input {
  text-align: center;
  font-size: 1.5rem;
  font-family: 'DM Sans', monospace;
  letter-spacing: 0.5rem;
  padding-left: 1.5rem;
}

.auth-button {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
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
  transition: all 0.25s cubic-bezier(0.34, 1.3, 0.64, 1);
  overflow: hidden;
}

.auth-button::before {
  content: '';
  position: absolute;
  inset: -6px;
  background: linear-gradient(135deg, var(--purple-deep), var(--cyan-dim));
  border-radius: calc(var(--radius-sm) + 6px);
  filter: blur(16px);
  opacity: 0.4;
  z-index: -1;
  transition: opacity 0.25s ease;
}

.auth-button:hover:not(:disabled) {
  transform: translateY(-2px);
}

.auth-button:hover:not(:disabled)::before {
  opacity: 0.6;
}

.auth-button:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.auth-button:disabled::before {
  opacity: 0.2;
}
</style>
