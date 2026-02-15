export interface AuthConfig {
  apiUrl: string
}

const API_URL = 'https://api.shychedelic.com'

export const AUTH_CONFIG: AuthConfig = {
  apiUrl: import.meta.env.PROD ? API_URL : '/api'
}
