<script setup lang="ts">
import { ref } from 'vue'
import { useAuthStore } from '@/stores/auth'

const authStore = useAuthStore()
const email = ref('')

function handleSubmit(): void {
  if (!email.value.trim()) return
  authStore.forgotPassword(email.value.trim())
}
</script>

<template>
  <form @submit.prevent="handleSubmit" class="stage">
    <div class="stage-header">
      <h3 class="stage-title">Reset password</h3>
      <p class="stage-subtitle">Enter your email and we'll send a reset link</p>
    </div>

    <div class="input-group">
      <input
        v-model="email"
        type="email"
        class="auth-input"
        placeholder="Email"
        autocomplete="email"
        autofocus
      />
    </div>

    <button type="submit" class="auth-button" :disabled="!email.trim() || authStore.isLoading">
      {{ authStore.isLoading ? 'Sending...' : 'Send reset link' }}
    </button>

    <div class="stage-footer">
      <button type="button" class="link-button" @click="authStore.switchView('login')">
        Back to sign in
      </button>
    </div>
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

.stage-footer {
  text-align: center;
}

.link-button {
  background: none;
  border: none;
  color: var(--text-secondary);
  font-size: 0.85rem;
  cursor: pointer;
  transition: color var(--transition-base);
}

.link-button:hover {
  color: var(--purple-bright);
}
</style>
