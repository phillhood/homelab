import { ref, onUnmounted, type Ref } from 'vue'
import type { WebSocketStatus } from '@/types'

export interface UseWebSocketReturn {
  data: Ref<unknown>
  status: Ref<WebSocketStatus>
  error: Ref<string | null>
  connect: () => void
  disconnect: () => void
  send: (message: unknown) => void
}

export function useWebSocket(url: string): UseWebSocketReturn {
  const data = ref<unknown>(null)
  const status = ref<WebSocketStatus>('disconnected')
  const error = ref<string | null>(null)

  let ws: WebSocket | null = null
  let reconnectTimeout: ReturnType<typeof setTimeout> | null = null
  let reconnectAttempts = 0
  const maxReconnectAttempts = 5
  const reconnectDelay = 3000

  function connect(): void {
    if (ws?.readyState === WebSocket.OPEN) return

    status.value = 'connecting'
    error.value = null

    try {
      ws = new WebSocket(url)

      ws.onopen = () => {
        status.value = 'connected'
        reconnectAttempts = 0
      }

      ws.onmessage = (event: MessageEvent) => {
        try {
          data.value = JSON.parse(event.data as string)
        } catch {
          data.value = event.data
        }
      }

      ws.onerror = () => {
        error.value = 'Connection error'
        status.value = 'error'
      }

      ws.onclose = () => {
        status.value = 'disconnected'
        attemptReconnect()
      }
    } catch (e) {
      error.value = e instanceof Error ? e.message : 'Unknown error'
      status.value = 'error'
    }
  }

  function disconnect(): void {
    if (reconnectTimeout) {
      clearTimeout(reconnectTimeout)
      reconnectTimeout = null
    }
    reconnectAttempts = maxReconnectAttempts

    if (ws) {
      ws.close()
      ws = null
    }
    status.value = 'disconnected'
  }

  function send(message: unknown): void {
    if (ws?.readyState === WebSocket.OPEN) {
      ws.send(typeof message === 'string' ? message : JSON.stringify(message))
    }
  }

  function attemptReconnect(): void {
    if (reconnectAttempts >= maxReconnectAttempts) return

    reconnectAttempts++
    reconnectTimeout = setTimeout(() => {
      connect()
    }, reconnectDelay * reconnectAttempts)
  }

  onUnmounted(() => {
    disconnect()
  })

  return {
    data,
    status,
    error,
    connect,
    disconnect,
    send
  }
}
