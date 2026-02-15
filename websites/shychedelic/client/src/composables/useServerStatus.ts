import { computed, type ComputedRef } from 'vue'
import { useServersStore } from '@/stores/servers'
import type { Server, OverallStatus } from '@/types'

export interface UseServerStatusReturn {
  servers: ComputedRef<Server[]>
  loading: ComputedRef<boolean>
  error: ComputedRef<string | null>
  overallStatus: ComputedRef<OverallStatus>
  statusText: ComputedRef<string>
  refresh: () => Promise<void>
}

export function useServerStatus(): UseServerStatusReturn {
  const store = useServersStore()

  const servers = computed(() => store.servers)
  const loading = computed(() => store.loading)
  const error = computed(() => store.error)

  const overallStatus = computed<OverallStatus>(() => {
    if (loading.value) return 'pending'
    if (error.value) return 'offline'
    if (servers.value.length === 0) return 'pending'

    const onlineCount = servers.value.filter(s => s.status === 'online').length
    if (onlineCount === servers.value.length) return 'online'
    if (onlineCount > 0) return 'partial'
    return 'offline'
  })

  const statusText = computed(() => {
    switch (overallStatus.value) {
      case 'online': return 'All systems operational'
      case 'partial': return 'Some services degraded'
      case 'offline': return 'Services unavailable'
      case 'pending': return 'Checking status...'
      default: return 'Unknown'
    }
  })

  async function refresh(): Promise<void> {
    await store.fetchServers()
  }

  return {
    servers,
    loading,
    error,
    overallStatus,
    statusText,
    refresh
  }
}
