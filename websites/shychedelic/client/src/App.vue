<script setup lang="ts">
import { onMounted } from 'vue'
import AppBackground from '@/components/layout/AppBackground.vue'
import AppHeader from '@/components/layout/AppHeader.vue'
import AuthModal from '@/components/auth/AuthModal.vue'
import { useAuthStore } from '@/stores/auth'

const authStore = useAuthStore()

onMounted(() => {
  authStore.loadUserFromToken()
})
</script>

<template>
  <AppBackground />
  <div class="app-content">
    <AppHeader />
    <main class="main">
      <RouterView v-slot="{ Component, route }">
        <Transition name="fade" mode="out-in">
          <component :is="Component" :key="route.path" />
        </Transition>
      </RouterView>
    </main>
  </div>
  <AuthModal />
</template>

<style scoped>
.app-content {
  position: relative;
  z-index: 2;
  min-height: 100vh;
  display: flex;
  flex-direction: column;
}

.main {
  flex: 1;
  display: flex;
  flex-direction: column;
}

.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.2s ease;
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}
</style>
