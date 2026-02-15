export type UserRole = 'admin' | 'user'

export interface User {
  id: string
  username: string
  email: string
  displayName?: string
  emailVerified?: boolean
  role?: UserRole
  matrixUserId?: string
  createdAt?: string
}

export interface AuthTokens {
  accessToken: string
  refreshToken: string
}

export interface LoginResponse {
  requiresTotp: boolean
  totpChallenge?: string
  accessToken?: string
  refreshToken?: string
  user?: User
}

export interface RegisterResponse {
  user: User
}

export type AuthView = 'login' | 'register' | 'totp' | 'forgot-password'
