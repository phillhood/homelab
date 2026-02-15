import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { useApi } from '@/composables/useApi'
import type { User, AuthView } from '@/types'

export const useAuthStore = defineStore('auth', () => {
  const api = useApi()

  const user = ref<User | null>(null)
  const accessToken = ref<string | null>(localStorage.getItem('auth_access_token'))
  const refreshToken = ref<string | null>(localStorage.getItem('auth_refresh_token'))

  const showModal = ref(false)
  const authView = ref<AuthView>('login')
  const isLoading = ref(false)
  const error = ref<string | null>(null)
  const successMessage = ref<string | null>(null)

  const totpChallenge = ref<string | null>(null)

  const isAuthenticated = computed(() => !!accessToken.value && !!user.value)

  function openModal(view: AuthView = 'login'): void {
    authView.value = view
    error.value = null
    successMessage.value = null
    showModal.value = true
  }

  function closeModal(): void {
    showModal.value = false
    error.value = null
    successMessage.value = null
    totpChallenge.value = null
  }

  function setTokens(access: string, refresh: string): void {
    accessToken.value = access
    refreshToken.value = refresh
    localStorage.setItem('auth_access_token', access)
    localStorage.setItem('auth_refresh_token', refresh)
  }

  function clearTokens(): void {
    accessToken.value = null
    refreshToken.value = null
    localStorage.removeItem('auth_access_token')
    localStorage.removeItem('auth_refresh_token')
  }

  async function login(identifier: string, password: string): Promise<void> {
    isLoading.value = true
    error.value = null

    try {
      const response = await api.login(identifier, password)

      if (response.requiresTotp) {
        totpChallenge.value = response.totpChallenge ?? null
        authView.value = 'totp'
        return
      }

      if (response.accessToken && response.refreshToken) {
        setTokens(response.accessToken, response.refreshToken)
        user.value = response.user ?? null
        closeModal()
      }
    } catch (err) {
      error.value = err instanceof Error ? err.message : 'Login failed'
    } finally {
      isLoading.value = false
    }
  }

  async function register(
    email: string,
    username: string,
    password: string,
    inviteCode?: string,
  ): Promise<void> {
    isLoading.value = true
    error.value = null

    try {
      await api.register(email, username, password, inviteCode)
      successMessage.value = 'Account created! Check your email to verify.'
      authView.value = 'login'
    } catch (err) {
      error.value = err instanceof Error ? err.message : 'Registration failed'
    } finally {
      isLoading.value = false
    }
  }

  async function verifyTotp(code: string): Promise<void> {
    if (!totpChallenge.value) return

    isLoading.value = true
    error.value = null

    try {
      const response = await api.totpVerify(totpChallenge.value, code)
      if (response.accessToken && response.refreshToken) {
        setTokens(response.accessToken, response.refreshToken)
        user.value = response.user ?? null
        totpChallenge.value = null
        closeModal()
      }
    } catch (err) {
      error.value = err instanceof Error ? err.message : 'Invalid code'
    } finally {
      isLoading.value = false
    }
  }

  async function forgotPassword(email: string): Promise<void> {
    isLoading.value = true
    error.value = null

    try {
      await api.forgotPassword(email)
      successMessage.value = 'If an account exists, a reset link has been sent'
    } catch (err) {
      error.value = err instanceof Error ? err.message : 'Request failed'
    } finally {
      isLoading.value = false
    }
  }

  async function refreshAccessToken(): Promise<boolean> {
    if (!refreshToken.value) return false

    try {
      const response = await api.refresh(refreshToken.value)
      setTokens(response.accessToken, response.refreshToken)
      user.value = response.user
      return true
    } catch {
      await logout()
      return false
    }
  }

  async function logout(): Promise<void> {
    if (refreshToken.value) {
      try {
        await api.logout(refreshToken.value)
      } catch {
        // ignore errors during logout
      }
    }

    user.value = null
    clearTokens()
    totpChallenge.value = null
  }

  async function loadUserFromToken(): Promise<void> {
    if (!accessToken.value) return

    try {
      user.value = await api.getMe()
    } catch {
      const refreshed = await refreshAccessToken()
      if (refreshed) {
        try {
          user.value = await api.getMe()
        } catch {
          await logout()
        }
      }
    }
  }

  function switchView(view: AuthView): void {
    authView.value = view
    error.value = null
    successMessage.value = null
  }

  return {
    user,
    accessToken,
    refreshToken,
    showModal,
    authView,
    isLoading,
    error,
    successMessage,
    totpChallenge,
    isAuthenticated,
    openModal,
    closeModal,
    login,
    register,
    verifyTotp,
    forgotPassword,
    refreshAccessToken,
    logout,
    loadUserFromToken,
    switchView,
  }
})
