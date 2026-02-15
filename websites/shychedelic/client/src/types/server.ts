export type ServerStatus = 'online' | 'offline' | 'pending'

export type GameType = 'minecraft' | 'valheim'

export interface ServerPlayers {
  online: number
  max: number
}

export interface Server {
  id: string
  name: string
  game: GameType
  status: ServerStatus
  address: string
  players?: ServerPlayers
}

export type OverallStatus = 'online' | 'offline' | 'partial' | 'pending'
