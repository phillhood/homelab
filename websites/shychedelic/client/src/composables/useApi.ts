import { AUTH_CONFIG } from '@/config/auth'
import type { User, LoginResponse, RegisterResponse, AuthTokens } from '@/types'

class ApiError extends Error {
  constructor(
    public status: number,
    message: string,
  ) {
    super(message)
  }
}

async function request<T>(
  path: string,
  options: RequestInit = {},
): Promise<T> {
  const url = `${AUTH_CONFIG.apiUrl}${path}`
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    ...((options.headers as Record<string, string>) || {}),
  }

  const token = localStorage.getItem('auth_access_token')
  if (token) {
    headers['Authorization'] = `Bearer ${token}`
  }

  const response = await fetch(url, {
    ...options,
    headers,
  })

  if (!response.ok) {
    const data = await response.json().catch(() => ({})) as { message?: string | string[] }
    const message = Array.isArray(data.message) ? data.message[0] : data.message
    throw new ApiError(response.status, message || `Request failed: ${response.status}`)
  }

  return response.json() as Promise<T>
}

export function useApi() {
  async function login(identifier: string, password: string): Promise<LoginResponse> {
    return request<LoginResponse>('/auth/login', {
      method: 'POST',
      body: JSON.stringify({ identifier, password }),
    })
  }

  async function register(
    email: string,
    username: string,
    password: string,
    inviteCode?: string,
    displayName?: string,
  ): Promise<RegisterResponse> {
    return request<RegisterResponse>('/auth/register', {
      method: 'POST',
      body: JSON.stringify({ email, username, password, inviteCode, displayName }),
    })
  }

  async function refresh(refreshToken: string): Promise<AuthTokens & { user: User }> {
    return request<AuthTokens & { user: User }>('/auth/refresh', {
      method: 'POST',
      body: JSON.stringify({ refreshToken }),
    })
  }

  async function logout(refreshToken: string): Promise<void> {
    await request('/auth/logout', {
      method: 'POST',
      body: JSON.stringify({ refreshToken }),
    })
  }

  async function getMe(): Promise<User> {
    return request<User>('/auth/me')
  }

  async function totpVerify(totpChallenge: string, code: string): Promise<LoginResponse> {
    return request<LoginResponse>('/auth/totp/verify', {
      method: 'POST',
      body: JSON.stringify({ totpChallenge, code }),
    })
  }

  async function totpSetup(): Promise<{ secret: string; qrUrl: string }> {
    return request('/auth/totp/setup', { method: 'POST' })
  }

  async function totpEnable(code: string): Promise<{ backupCodes: string[] }> {
    return request('/auth/totp/enable', {
      method: 'POST',
      body: JSON.stringify({ code }),
    })
  }

  async function totpDisable(password: string): Promise<void> {
    await request('/auth/totp/disable', {
      method: 'POST',
      body: JSON.stringify({ password }),
    })
  }

  async function forgotPassword(email: string): Promise<void> {
    await request('/auth/forgot-password', {
      method: 'POST',
      body: JSON.stringify({ email }),
    })
  }

  async function resetPassword(token: string, newPassword: string): Promise<void> {
    await request('/auth/reset-password', {
      method: 'POST',
      body: JSON.stringify({ token, newPassword }),
    })
  }

  async function verifyEmail(token: string): Promise<void> {
    await request('/auth/verify-email', {
      method: 'POST',
      body: JSON.stringify({ token }),
    })
  }

  async function getMatrixLoginToken(): Promise<{ loginToken: string; elementUrl: string }> {
    return request('/matrix/login-token', { method: 'POST' })
  }

  return {
    login,
    register,
    refresh,
    logout,
    getMe,
    totpVerify,
    totpSetup,
    totpEnable,
    totpDisable,
    forgotPassword,
    resetPassword,
    verifyEmail,
    getMatrixLoginToken,
  }
}
