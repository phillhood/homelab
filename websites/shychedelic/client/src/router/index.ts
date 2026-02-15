import { createRouter, createWebHistory, type RouteRecordRaw } from 'vue-router'

const routes: RouteRecordRaw[] = [
  {
    path: '/',
    name: 'home',
    component: () => import('@/views/HomeView.vue')
  },
  {
    path: '/servers',
    name: 'servers',
    component: () => import('@/views/ServersView.vue')
  },
  {
    path: '/matrix',
    name: 'matrix',
    component: () => import('@/views/MatrixView.vue')
  },
  {
    path: '/callback',
    name: 'auth-callback',
    component: () => import('@/views/AuthCallbackView.vue')
  },
  {
    path: '/auth/verify-email',
    name: 'verify-email',
    component: () => import('@/views/AuthCallbackView.vue')
  },
  {
    path: '/auth/reset-password',
    name: 'reset-password',
    component: () => import('@/views/ResetPasswordView.vue')
  }
]

const router = createRouter({
  history: createWebHistory(),
  routes
})

export default router
