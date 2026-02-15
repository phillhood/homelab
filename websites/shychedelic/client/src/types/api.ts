export interface ApiResponse<T> {
  data: T
  status: number
  message?: string
}

export interface ApiError {
  message: string
  code?: string
  status?: number
  detail?: string
}

export type WebSocketStatus = 'connecting' | 'connected' | 'disconnected' | 'error'
