import { defineStore } from 'pinia'
import { ref } from 'vue'
import type { Server, ServerStatus } from '@/types'

export const useServersStore = defineStore('servers', () => {
  const servers = ref<Server[]>([])
  const loading = ref(false)
  const error = ref<string | null>(null)

  async function fetchServers(): Promise<void> {
    loading.value = true
    error.value = null

    try {
      // TODO: Implement actual API call
      // const response = await fetch('/api/servers')
      // servers.value = await response.json()

      servers.value = [
        {
          id: 'minecraft',
          name: 'Minecraft',
          game: 'minecraft',
          status: 'offline',
          address: 'mc.shychedelic.com',
          players: { online: 0, max: 20 }
        },
        {
          id: 'valheim',
          name: 'Valheim',
          game: 'valheim',
          status: 'offline',
          address: 'valheim.shychedelic.com'
        }
      ]
    } catch (e) {
      error.value = e instanceof Error ? e.message : 'Unknown error'
    } finally {
      loading.value = false
    }
  }

  function updateServerStatus(serverId: string, status: ServerStatus): void {
    const server = servers.value.find(s => s.id === serverId)
    if (server) {
      server.status = status
    }
  }

  return {
    servers,
    loading,
    error,
    fetchServers,
    updateServerStatus
  }
})
