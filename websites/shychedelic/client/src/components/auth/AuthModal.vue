<script setup lang="ts">
import { watch, onMounted, onUnmounted } from 'vue'
import { useAuthStore } from '@/stores/auth'
import AuthForm from './AuthForm.vue'

const authStore = useAuthStore()

function handleEscape(e: KeyboardEvent): void {
  if (e.key === 'Escape' && authStore.showModal) {
    authStore.closeModal()
  }
}

function handleBackdropClick(e: MouseEvent): void {
  if (e.target === e.currentTarget) {
    authStore.closeModal()
  }
}

watch(() => authStore.showModal, (show) => {
  if (show) {
    document.body.style.overflow = 'hidden'
  } else {
    document.body.style.overflow = ''
  }
})

onMounted(() => {
  document.addEventListener('keydown', handleEscape)
})

onUnmounted(() => {
  document.removeEventListener('keydown', handleEscape)
  document.body.style.overflow = ''
})
</script>

<template>
  <Teleport to="body">
    <Transition name="modal">
      <div
        v-if="authStore.showModal"
        class="modal-backdrop"
        @click="handleBackdropClick"
      >
        <div class="modal-card">
          <button
            class="modal-close"
            @click="authStore.closeModal()"
            aria-label="Close"
          >
            <svg viewBox="0 0 24 24">
              <path d="M18 6L6 18M6 6l12 12" />
            </svg>
          </button>

          <div class="modal-glow" />
          <AuthForm />
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
.modal-backdrop {
  position: fixed;
  inset: 0;
  z-index: 1000;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 1.5rem;
  background: rgba(0, 0, 0, 0.75);
  backdrop-filter: blur(12px);
}

.modal-card {
  position: relative;
  width: 100%;
  max-width: 420px;
  padding: 2.5rem 2rem 2rem;
  background: linear-gradient(
    165deg,
    rgba(24, 24, 36, 0.98) 0%,
    rgba(14, 14, 22, 0.98) 100%
  );
  border: 1px solid var(--glass-border);
  border-radius: var(--radius-lg);
  box-shadow:
    0 0 0 1px rgba(255, 255, 255, 0.03) inset,
    0 32px 64px -12px rgba(0, 0, 0, 0.5),
    0 0 120px -20px rgba(124, 58, 237, 0.15);
  overflow: hidden;
}

.modal-glow {
  position: absolute;
  top: -100px;
  left: 50%;
  transform: translateX(-50%);
  width: 300px;
  height: 200px;
  background: radial-gradient(
    ellipse at center,
    rgba(168, 85, 247, 0.12) 0%,
    rgba(6, 182, 212, 0.06) 40%,
    transparent 70%
  );
  pointer-events: none;
  filter: blur(40px);
}

.modal-card::before {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  height: 1px;
  background: linear-gradient(
    90deg,
    transparent 0%,
    rgba(168, 85, 247, 0.4) 30%,
    rgba(6, 182, 212, 0.4) 70%,
    transparent 100%
  );
}

.modal-close {
  position: absolute;
  top: 0.5rem;
  right: 0.5rem;
  width: 28px;
  height: 28px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: none;
  border: none;
  border-radius: 6px;
  cursor: pointer;
  opacity: 0.5;
  transition: opacity 0.2s cubic-bezier(0.16, 1, 0.3, 1),
              transform 0.15s cubic-bezier(0.34, 1.3, 0.64, 1);
  z-index: 10;
}

.modal-close:hover {
  opacity: 1;
}

.modal-close:active {
  transform: scale(0.9);
}

.modal-close svg {
  width: 14px;
  height: 14px;
  stroke: var(--text-secondary);
  stroke-width: 2.5;
  stroke-linecap: round;
  fill: none;
}

.modal-close:hover svg {
  stroke: var(--text-primary);
}

/* Unified motion system - backdrop and card animate together */
.modal-enter-active {
  transition: opacity 0.3s cubic-bezier(0.16, 1, 0.3, 1);
}

.modal-leave-active {
  transition: opacity 0.2s cubic-bezier(0.4, 0, 1, 1);
}

.modal-enter-active .modal-card {
  transition: transform 0.4s cubic-bezier(0.34, 1.3, 0.64, 1);
}

.modal-leave-active .modal-card {
  transition: transform 0.2s cubic-bezier(0.4, 0, 1, 1);
}

.modal-enter-from,
.modal-leave-to {
  opacity: 0;
}

.modal-enter-from .modal-card {
  transform: scale(0.95) translateY(12px);
}

.modal-leave-to .modal-card {
  transform: scale(0.98) translateY(-6px);
}

@media (max-width: 480px) {
  .modal-backdrop {
    padding: 1rem;
  }

  .modal-card {
    max-width: none;
    padding: 2rem 1.25rem 1.5rem;
  }
}
</style>
