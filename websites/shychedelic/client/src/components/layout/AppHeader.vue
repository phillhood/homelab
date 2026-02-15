<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue'
import { useAuthStore } from '@/stores/auth'
import LogoIcon from '@/assets/icons/logo.svg'

const authStore = useAuthStore()
const isDropdownOpen = ref(false)
const dropdownRef = ref<HTMLElement | null>(null)

function handleSignIn(): void {
  authStore.openModal('login')
}

function toggleDropdown(): void {
  isDropdownOpen.value = !isDropdownOpen.value
}

function closeDropdown(): void {
  isDropdownOpen.value = false
}

function handleSignOut(): void {
  closeDropdown()
  authStore.logout()
}

function handleClickOutside(e: MouseEvent): void {
  if (dropdownRef.value && !dropdownRef.value.contains(e.target as Node)) {
    closeDropdown()
  }
}

onMounted(() => {
  document.addEventListener('click', handleClickOutside)
})

onUnmounted(() => {
  document.removeEventListener('click', handleClickOutside)
})
</script>

<template>
  <header class="app-header">
    <div class="header-content">
      <RouterLink to="/" class="header-brand">
        <img :src="LogoIcon" alt="Shychedelic" class="header-logo" />
        <span class="header-title">Shychedelic</span>
      </RouterLink>

      <nav class="header-nav">
        <template v-if="authStore.isAuthenticated">
          <div ref="dropdownRef" class="user-menu">
            <button class="user-chip" @click="toggleDropdown">
              <span class="status-dot" />
              <div class="user-avatar">
                {{ authStore.user?.username?.charAt(0).toUpperCase() }}
              </div>
              <span class="user-name">{{ authStore.user?.username }}</span>
              <svg class="chevron" :class="{ open: isDropdownOpen }" viewBox="0 0 24 24">
                <path d="M6 9l6 6 6-6" />
              </svg>
            </button>

            <Transition name="dropdown">
              <div v-if="isDropdownOpen" class="dropdown">
                <div class="dropdown-header">
                  <div class="dropdown-avatar">
                    {{ authStore.user?.username?.charAt(0).toUpperCase() }}
                  </div>
                  <div class="dropdown-user">
                    <span class="dropdown-name">{{ authStore.user?.displayName || authStore.user?.username }}</span>
                    <span class="dropdown-email">{{ authStore.user?.email }}</span>
                  </div>
                </div>

                <div class="dropdown-divider" />

                <button class="dropdown-item dropdown-item--danger" @click="handleSignOut">
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
        <template v-else>
          <button class="auth-btn auth-btn--primary" @click="handleSignIn">
            <svg viewBox="0 0 24 24" class="auth-icon">
              <path d="M15 3h4a2 2 0 012 2v14a2 2 0 01-2 2h-4" />
              <polyline points="10,17 15,12 10,7" />
              <line x1="15" y1="12" x2="3" y2="12" />
            </svg>
            Sign in
          </button>
        </template>
      </nav>
    </div>
  </header>
</template>

<style scoped>
.app-header {
  position: sticky;
  top: 0;
  z-index: 100;
  padding: 0 1.5rem;
  background: rgba(10, 10, 15, 0.4);
  backdrop-filter: blur(12px) saturate(180%);
  -webkit-backdrop-filter: blur(12px) saturate(180%);
  border-bottom: 1px solid var(--glass-border);
}

.app-header::before {
  content: '';
  position: absolute;
  inset: 0;
  background: linear-gradient(
    180deg,
    rgba(255, 255, 255, 0.03) 0%,
    transparent 100%
  );
  pointer-events: none;
}

.app-header::after {
  content: '';
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  height: 1px;
  background: linear-gradient(
    90deg,
    transparent 0%,
    rgba(168, 85, 247, 0.2) 25%,
    rgba(6, 182, 212, 0.15) 75%,
    transparent 100%
  );
  pointer-events: none;
}

.header-content {
  max-width: 1200px;
  margin: 0 auto;
  height: 64px;
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.header-brand {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  text-decoration: none;
  transition: opacity 0.2s ease;
}

.header-brand:hover {
  opacity: 0.85;
}

.header-logo {
  width: 32px;
  height: 32px;
}

.header-title {
  font-family: 'Sora', sans-serif;
  font-size: 1.125rem;
  font-weight: 600;
  background: linear-gradient(135deg, var(--text-primary) 0%, var(--purple-bright) 100%);
  -webkit-background-clip: text;
  background-clip: text;
  -webkit-text-fill-color: transparent;
}

.header-nav {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.user-menu {
  position: relative;
}

.user-chip {
  position: relative;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.375rem 0.625rem 0.375rem 0.375rem;
  background: var(--glass-bg);
  border: 1px solid var(--glass-border);
  border-radius: var(--radius-sm);
  cursor: pointer;
  transition: all var(--transition-fast);
}

.user-chip::before {
  content: '';
  position: absolute;
  inset: 0;
  border-radius: var(--radius-sm);
  padding: 1px;
  background: linear-gradient(135deg, var(--glass-highlight), transparent 60%);
  -webkit-mask: linear-gradient(#fff 0 0) content-box, linear-gradient(#fff 0 0);
  mask: linear-gradient(#fff 0 0) content-box, linear-gradient(#fff 0 0);
  -webkit-mask-composite: xor;
  mask-composite: exclude;
  pointer-events: none;
  opacity: 0;
  transition: opacity var(--transition-fast);
}

.user-chip:hover,
.user-chip:focus {
  background: rgba(255, 255, 255, 0.05);
  border-color: var(--glass-highlight);
  outline: none;
}

.user-chip:hover::before,
.user-chip:focus::before {
  opacity: 1;
}

.status-dot {
  position: absolute;
  top: 0.375rem;
  left: 0.375rem;
  width: 7px;
  height: 7px;
  background: var(--status-online);
  border-radius: 50%;
  border: 2px solid var(--void);
  box-shadow: 0 0 6px var(--status-online);
  z-index: 1;
}

.user-avatar {
  width: 26px;
  height: 26px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, var(--purple-deep) 0%, var(--purple-bright) 100%);
  border-radius: 6px;
  font-family: 'Sora', sans-serif;
  font-size: 0.75rem;
  font-weight: 600;
  color: white;
}

.user-name {
  font-family: 'DM Sans', sans-serif;
  font-size: 0.8rem;
  font-weight: 500;
  color: var(--text-primary);
  max-width: 100px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.chevron {
  width: 14px;
  height: 14px;
  stroke: var(--text-muted);
  stroke-width: 2;
  stroke-linecap: round;
  stroke-linejoin: round;
  fill: none;
  transition: transform 0.2s cubic-bezier(0.34, 1.3, 0.64, 1);
}

.chevron.open {
  transform: rotate(180deg);
}

.dropdown {
  position: absolute;
  top: calc(100% + 8px);
  right: 0;
  min-width: 220px;
  background: rgba(18, 18, 26, 0.98);
  border: 1px solid var(--glass-border);
  border-radius: var(--radius-md);
  box-shadow:
    0 0 0 1px rgba(255, 255, 255, 0.02) inset,
    0 16px 48px -8px rgba(0, 0, 0, 0.5),
    0 0 60px -20px rgba(124, 58, 237, 0.1);
  overflow: hidden;
  z-index: 200;
}

.dropdown::before {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  height: 1px;
  background: linear-gradient(
    90deg,
    transparent 0%,
    rgba(168, 85, 247, 0.3) 50%,
    transparent 100%
  );
}

.dropdown-header {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 1rem;
}

.dropdown-avatar {
  width: 36px;
  height: 36px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, var(--purple-deep) 0%, var(--purple-bright) 100%);
  border-radius: 8px;
  font-family: 'Sora', sans-serif;
  font-size: 0.9rem;
  font-weight: 600;
  color: white;
}

.dropdown-user {
  display: flex;
  flex-direction: column;
  gap: 0.125rem;
  min-width: 0;
}

.dropdown-name {
  font-family: 'Sora', sans-serif;
  font-size: 0.85rem;
  font-weight: 500;
  color: var(--text-primary);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.dropdown-email {
  font-size: 0.75rem;
  color: var(--text-muted);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.dropdown-divider {
  height: 1px;
  margin: 0 0.75rem;
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
  font-family: 'DM Sans', sans-serif;
  font-size: 0.85rem;
  color: var(--text-primary);
  text-align: left;
  cursor: pointer;
  transition: background var(--transition-fast);
}

.dropdown-item:hover {
  background: rgba(255, 255, 255, 0.04);
}

.dropdown-item svg {
  width: 16px;
  height: 16px;
  stroke: var(--text-secondary);
  stroke-width: 2;
  stroke-linecap: round;
  stroke-linejoin: round;
  fill: none;
  transition: stroke var(--transition-fast);
}

.dropdown-item:hover svg {
  stroke: var(--text-primary);
}

.dropdown-item--danger {
  color: rgba(248, 113, 113, 0.9);
}

.dropdown-item--danger svg {
  stroke: rgba(248, 113, 113, 0.7);
}

.dropdown-item--danger:hover {
  background: rgba(239, 68, 68, 0.08);
}

.dropdown-item--danger:hover svg {
  stroke: rgba(248, 113, 113, 1);
}

.dropdown-enter-active {
  transition: all 0.2s cubic-bezier(0.16, 1, 0.3, 1);
}

.dropdown-leave-active {
  transition: all 0.15s cubic-bezier(0.4, 0, 1, 1);
}

.dropdown-enter-from,
.dropdown-leave-to {
  opacity: 0;
  transform: translateY(-8px) scale(0.96);
}

.auth-btn {
  position: relative;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.5rem 1rem;
  border-radius: 8px;
  font-family: 'DM Sans', sans-serif;
  font-size: 0.85rem;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.25s cubic-bezier(0.34, 1.3, 0.64, 1);
  overflow: hidden;
}

.auth-btn--primary {
  background: linear-gradient(135deg, var(--purple-deep) 0%, var(--cyan-dim) 100%);
  border: none;
  color: white;
}

.auth-btn--primary::before {
  content: '';
  position: absolute;
  inset: -4px;
  background: linear-gradient(135deg, var(--purple-deep), var(--cyan-dim));
  border-radius: 12px;
  filter: blur(12px);
  opacity: 0.4;
  z-index: -1;
  transition: opacity 0.25s ease;
}

.auth-btn--primary:hover {
  transform: translateY(-2px);
}

.auth-btn--primary:hover::before {
  opacity: 0.6;
}

.auth-btn--primary:active {
  transform: translateY(0);
}

.auth-icon {
  width: 16px;
  height: 16px;
  stroke: currentColor;
  stroke-width: 2;
  stroke-linecap: round;
  stroke-linejoin: round;
  fill: none;
}

@media (max-width: 640px) {
  .app-header {
    padding: 0 1rem;
  }

  .header-content {
    height: 56px;
  }

  .header-title {
    display: none;
  }

  .user-name {
    display: none;
  }

  .user-chip {
    padding: 0.25rem 0.5rem 0.25rem 0.25rem;
  }

  .dropdown {
    min-width: 200px;
  }
}
</style>
