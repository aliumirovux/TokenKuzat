export type Status = 'idle' | 'thinking' | 'working' | 'waiting' | 'error' | 'done'

export type Bot = {
  id: string
  name: string
  isMain: boolean
  status: Status
  tool?: string
  running: number
  // when the status last changed, ms since the epoch
  since: number
  // when the main agent handed this helper its task
  spawnedAt: number
  // helper desk 0..5; -1 has no desk (shown in the list only)
  slot: number
  color: string
}

export type Office = { bots: Bot[] }

declare module 'claude-code' {
  interface PluginState {
    tokenkuzat: { office: Shaped<Office>; tick: Shaped<number> }
  }
}
