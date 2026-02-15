<script setup lang="ts">
import { ref } from 'vue'
import { useAuthStore } from '@/stores/auth'

const authStore = useAuthStore()

const identifier = ref('')
const password = ref('')
const showPassword = ref(false)
const identifierRef = ref<HTMLInputElement | null>(null)

function handleSubmit(): void {
  if (!identifier.value.trim() || !password.value) return
  authStore.login(identifier.value.trim(), password.value)
}

defineExpose({
  focus: () => identifierRef.value?.focus()
})
</script>

<template>
  <form @submit.prevent="handleSubmit" class="stage">
    <div class="stage-header">
      <h3 class="stage-title">Sign in</h3>
      <p class="stage-subtitle">Enter your credentials</p>
    </div>

    <div class="input-group">
      <input
        ref="identifierRef"
        v-model="identifier"
        type="text"
        class="auth-input"
        placeholder="Email or username"
        autocomplete="username"
        autofocus
      />

      <div class="password-wrapper">
        <input
          v-model="password"
          :type="showPassword ? 'text' : 'password'"
          class="auth-input"
          placeholder="Password"
          autocomplete="current-password"
        />
        <button
          type="button"
          class="toggle-password"
          @click="showPassword = !showPassword"
          tabindex="-1"
        >
          <svg v-if="showPassword" viewBox="0 0 24 24" class="eye-icon">
            <path d="M17.94 17.94A10.07 10.07 0 0112 20c-7 0-11-8-11-8a18.45 18.45 0 015.06-5.94M9.9 4.24A9.12 9.12 0 0112 4c7 0 11 8 11 8a18.5 18.5 0 01-2.16 3.19m-6.72-1.07a3 3 0 11-4.24-4.24" />
            <line x1="1" y1="1" x2="23" y2="23" />
          </svg>
          <svg v-else viewBox="0 0 24 24" class="eye-icon">
            <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" />
            <circle cx="12" cy="12" r="3" />
          </svg>
        </button>
      </div>
    </div>

    <button type="submit" class="auth-button" :disabled="!identifier.trim() || !password || authStore.isLoading">
      {{ authStore.isLoading ? 'Signing in...' : 'Sign in' }}
    </button>

    <div class="stage-footer">
      <button type="button" class="link-button" @click="authStore.switchView('forgot-password')">
        Forgot password?
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
  gap: 0.75rem;
}

.password-wrapper {
  position: relative;
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

.password-wrapper .auth-input {
  padding-right: 3rem;
}

.auth-input:focus {
  outline: none;
  border-color: var(--purple-bright);
  box-shadow: 0 0 0 3px rgba(168, 85, 247, 0.15);
}

.auth-input::placeholder {
  color: var(--text-muted);
}

.toggle-password {
  position: absolute;
  right: 0.75rem;
  top: 50%;
  transform: translateY(-50%);
  background: none;
  border: none;
  padding: 0.25rem;
  cursor: pointer;
  opacity: 0.5;
  transition: opacity var(--transition-base);
}

.toggle-password:hover {
  opacity: 1;
}

.eye-icon {
  width: 20px;
  height: 20px;
  stroke: var(--text-secondary);
  stroke-width: 2;
  fill: none;
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
