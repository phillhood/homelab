<script setup lang="ts">
import { computed, type Component } from 'vue'
import { useAuthStore } from '@/stores/auth'
import LoginForm from './LoginForm.vue'
import RegisterForm from './RegisterForm.vue'
import TotpForm from './TotpForm.vue'
import ForgotPasswordForm from './ForgotPasswordForm.vue'
import type { AuthView } from '@/types'

const authStore = useAuthStore()

const showTabs = computed(() => authStore.authView === 'login' || authStore.authView === 'register')

const viewComponents: Record<AuthView, Component> = {
  login: LoginForm,
  register: RegisterForm,
  totp: TotpForm,
  'forgot-password': ForgotPasswordForm,
}

const currentComponent = computed(() => viewComponents[authStore.authView])

function switchTab(view: AuthView): void {
  if (authStore.authView !== view) {
    authStore.switchView(view)
  }
}
</script>

<template>
  <div class="auth-form">
    <div v-if="showTabs" class="auth-tabs">
      <button
        class="auth-tab"
        :class="{ active: authStore.authView === 'login' }"
        @click="switchTab('login')"
      >
        Sign in
      </button>
      <button
        class="auth-tab"
        :class="{ active: authStore.authView === 'register' }"
        @click="switchTab('register')"
      >
        Create account
      </button>
      <div
        class="tab-indicator"
        :class="{ right: authStore.authView === 'register' }"
      />
    </div>

    <Transition name="fade">
      <div v-if="authStore.successMessage" class="inline-success">
        {{ authStore.successMessage }}
      </div>
    </Transition>

    <div class="stage-container">
      <Transition name="stage" mode="out-in">
        <component
          :is="currentComponent"
          :key="authStore.authView"
        />
      </Transition>
    </div>

    <Transition name="fade">
      <div v-if="authStore.error" class="inline-error">
        {{ authStore.error }}
      </div>
    </Transition>
  </div>
</template>

<style scoped>
.auth-form {
  position: relative;
  display: flex;
  flex-direction: column;
  gap: 1.75rem;
}

.auth-tabs {
  position: relative;
  display: flex;
  gap: 4px;
  padding: 4px;
  background: rgba(255, 255, 255, 0.03);
  border: 1px solid rgba(255, 255, 255, 0.04);
  border-radius: var(--radius-md);
}

.auth-tab {
  flex: 1;
  padding: 0.625rem 0.75rem;
  background: none;
  border: none;
  color: var(--text-muted);
  font-family: 'Sora', sans-serif;
  font-size: 0.8rem;
  font-weight: 500;
  letter-spacing: 0.01em;
  cursor: pointer;
  transition: color 0.2s cubic-bezier(0.16, 1, 0.3, 1);
  position: relative;
  z-index: 1;
}

.auth-tab.active {
  color: var(--text-primary);
}

.auth-tab:hover:not(.active) {
  color: var(--text-secondary);
}

.tab-indicator {
  position: absolute;
  top: 4px;
  bottom: 4px;
  left: 4px;
  width: calc(50% - 6px);
  background: linear-gradient(
    135deg,
    rgba(168, 85, 247, 0.15) 0%,
    rgba(6, 182, 212, 0.1) 100%
  );
  border: 1px solid rgba(168, 85, 247, 0.2);
  border-radius: calc(var(--radius-md) - 4px);
  transition: transform 0.3s cubic-bezier(0.34, 1.3, 0.64, 1);
}

.tab-indicator.right {
  transform: translateX(calc(100% + 4px));
}

.stage-container {
  position: relative;
}

.inline-error {
  padding: 0.875rem 1rem;
  background: rgba(239, 68, 68, 0.08);
  border: 1px solid rgba(239, 68, 68, 0.2);
  border-radius: var(--radius-sm);
  color: rgba(248, 113, 113, 0.9);
  font-size: 0.8rem;
  line-height: 1.5;
  text-align: center;
}

.inline-success {
  padding: 0.875rem 1rem;
  background: rgba(34, 197, 94, 0.08);
  border: 1px solid rgba(34, 197, 94, 0.2);
  border-radius: var(--radius-sm);
  color: rgba(74, 222, 128, 0.9);
  font-size: 0.8rem;
  line-height: 1.5;
  text-align: center;
}

.stage-enter-active {
  transition: opacity 0.25s cubic-bezier(0.16, 1, 0.3, 1),
              transform 0.25s cubic-bezier(0.16, 1, 0.3, 1);
}

.stage-leave-active {
  transition: opacity 0.15s cubic-bezier(0.4, 0, 1, 1),
              transform 0.15s cubic-bezier(0.4, 0, 1, 1);
}

.stage-enter-from {
  opacity: 0;
  transform: translateX(8px);
}

.stage-leave-to {
  opacity: 0;
  transform: translateX(-8px);
}

.fade-enter-active {
  transition: opacity 0.2s cubic-bezier(0.16, 1, 0.3, 1);
}

.fade-leave-active {
  transition: opacity 0.15s cubic-bezier(0.4, 0, 1, 1);
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}
</style>
