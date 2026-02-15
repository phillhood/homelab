<script setup lang="ts">
import { ref } from 'vue'
import { useAuthStore } from '@/stores/auth'

const authStore = useAuthStore()
const isOpen = ref(false)

function toggleMenu(): void {
  isOpen.value = !isOpen.value
}

function closeMenu(): void {
  isOpen.value = false
}

function handleLogout(): void {
  authStore.logout()
  closeMenu()
}
</script>

<template>
  <div class="user-menu" v-click-outside="closeMenu">
    <button class="user-button" @click="toggleMenu">
      <div class="user-avatar">
        {{ authStore.user?.username?.charAt(0)?.toUpperCase() || '?' }}
      </div>
      <span class="user-name">{{ authStore.user?.username || 'User' }}</span>
      <svg class="chevron" :class="{ open: isOpen }" viewBox="0 0 24 24">
        <path d="M6 9l6 6 6-6" />
      </svg>
    </button>

    <Transition name="dropdown">
      <div v-if="isOpen" class="dropdown">
        <div class="dropdown-header">
          <div class="header-name">{{ authStore.user?.displayName || authStore.user?.username }}</div>
          <div class="header-email">{{ authStore.user?.email }}</div>
        </div>
        <div class="dropdown-divider" />
        <button class="dropdown-item" @click="handleLogout">
          <svg viewBox="0 0 24 24">
            <path d="M9 21H5a2 2 0 01-2-2V5a2 2 0 012-2h4" />
            <polyline points="16,17 21,12 16,7" />
            <line x1="21" y1="12" x2="9" y2="12" />
          </svg>
          Sign out
        </button>
      </div>
    </Transition>
  </div>
</template>

<style scoped>
.user-menu {
  position: relative;
}

.user-button {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.375rem 0.75rem 0.375rem 0.375rem;
  background: rgba(255, 255, 255, 0.05);
  border: 1px solid var(--glass-border);
  border-radius: var(--radius-sm);
  color: var(--text-primary);
  font-family: 'Sora', sans-serif;
  font-size: 0.85rem;
  cursor: pointer;
  transition: all var(--transition-base);
}

.user-button:hover {
  background: rgba(255, 255, 255, 0.08);
  border-color: var(--glass-highlight);
}

.user-avatar {
  width: 28px;
  height: 28px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, var(--purple-deep), var(--purple-bright));
  border-radius: 50%;
  font-size: 0.8rem;
  font-weight: 600;
}

.user-name {
  max-width: 100px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.chevron {
  width: 14px;
  height: 14px;
  stroke: var(--text-secondary);
  stroke-width: 2;
  fill: none;
  transition: transform var(--transition-base);
}

.chevron.open {
  transform: rotate(180deg);
}

.dropdown {
  position: absolute;
  top: calc(100% + 0.5rem);
  right: 0;
  min-width: 200px;
  background: rgba(18, 18, 26, 0.98);
  border: 1px solid var(--glass-border);
  border-radius: var(--radius-md);
  box-shadow: 0 12px 32px rgba(0, 0, 0, 0.4);
  overflow: hidden;
  z-index: 100;
}

.dropdown-header {
  padding: 0.875rem 1rem;
}

.header-name {
  font-weight: 500;
  margin-bottom: 0.25rem;
}

.header-email {
  font-size: 0.8rem;
  color: var(--text-secondary);
}

.dropdown-divider {
  height: 1px;
  background: var(--glass-border);
}

.dropdown-item {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  width: 100%;
  padding: 0.75rem 1rem;
  background: none;
  border: none;
  color: var(--text-primary);
  font-family: inherit;
  font-size: 0.875rem;
  text-align: left;
  cursor: pointer;
  transition: background var(--transition-base);
}

.dropdown-item:hover {
  background: rgba(255, 255, 255, 0.05);
}

.dropdown-item svg {
  width: 16px;
  height: 16px;
  stroke: var(--text-secondary);
  stroke-width: 2;
  fill: none;
}

.dropdown-enter-active,
.dropdown-leave-active {
  transition: all 0.2s ease;
}

.dropdown-enter-from,
.dropdown-leave-to {
  opacity: 0;
  transform: translateY(-8px);
}
</style>
