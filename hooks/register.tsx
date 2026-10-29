import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { Bot, Office, Status } from '../types'
import { COLORS, DONE_FOR, LABEL, MAIN_COLOR, SLEEP_AFTER, drawOffice, shown } from './scene'

const PANE = 'ofis'
const MAIN = 'main'
// Change the tag when Bot's fields change: it declines what an earlier version stored.
const office = atom({ plugin: 'tokenkuzat', key: 'office' } as const, { bots: [] }, { shape: 'office-1' })
// Bumped when a time-based change is due (done → idle, idle → asleep), so the pane redraws.
const tick = atom({ plugin: 'tokenkuzat', key: 'tick' } as const, 0, { shape: 'tick-1' })

const mainBot = (now: number): Bot => ({
  id: MAIN,
  name: 'Asosiy agent',
  isMain: true,
  status: 'idle',
  running: 0,
  since: now,
  spawnedAt: 0,
  slot: -1,
  color: MAIN_COLOR,
})

// A helper takes the first free desk; when all six are taken, the longest-finished
// helper leaves the office. With every desk busy it waits in the list only.
function addHelper(o: Office, id: string, name: string, now: number): Office {
  let bots = o.bots
  const taken = () => new Set(bots.filter(b => !b.isMain).map(b => b.slot))
  if (taken().size >= COLORS.length) {
    const gone = bots
      .filter(b => !b.isMain && b.status === 'done')
      .sort((a, b) => a.since - b.since)[0]
    if (gone) bots = bots.filter(b => b !== gone)
  }
  const used = taken()
  const slot = COLORS.findIndex((_, i) => !used.has(i))
  const helper: Bot = {
    id,
    name,
    isMain: false,
    status: 'thinking',
    running: 0,
    since: now,
    spawnedAt: now,
    slot,
    color: COLORS[slot >= 0 ? slot : bots.length % COLORS.length] ?? MAIN_COLOR,
  }
  return { bots: [...bots, helper] }
}

async function change($: EngineInterface, agentId: string | undefined, fn: (b: Bot) => Bot) {
  const id = agentId ?? MAIN
  const now = await $.clock.now()
  let next: Status | undefined
  await update($, office, o => {
    const base = o.bots.some(b => b.id === MAIN) ? o : { bots: [mainBot(now), ...o.bots] }
    const known = base.bots.some(b => b.id === id) ? base : addHelper(base, id, 'Yordamchi', now)
    return {
      bots: known.bots.map(b => {
        if (b.id !== id) return b
        const after = fn(b)
        next = after.status
        return after.status === b.status ? after : { ...after, since: now }
      }),
    }
  })
  // Time-based changes need a redraw of their own.
  const bump = () => void update($, tick, n => n + 1)
  if (next === 'done') $.clock.after(DONE_FOR + 200, bump)
  if (next === 'done' || next === 'idle') $.clock.after(SLEEP_AFTER + 500, bump)
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({ name: 'ofis', description: "Agentlar ofisini panelda ochadi" })
    const now = await $.clock.now()
    await update($, office, o => (o.bots.some(b => b.isMain) ? o : { bots: [mainBot(now), ...o.bots] }))
    void $.ui.open({ id: PANE, title: 'Ofis' })

    return next(e)
  })

  on('command.run', { command: 'ofis' }, async $ => {
    await $.ui.open({ id: PANE, title: 'Ofis' })

    return { text: 'Ofis paneli ochildi.' }
  })

  on('turn.start', async ($, e, next) => {
    await change($, e.agentId, b => ({ ...b, status: 'thinking', tool: undefined, running: 0 }))

    return next(e)
  })

  on('agent.spawn', async ($, e, next) => {
    const spawned = await next(e)
    if (spawned.agentId) {
      const id = spawned.agentId
      const name = e.description || e.subagentType || 'Yordamchi'
      const now = await $.clock.now()
      await update($, office, o => {
        const old = o.bots.find(b => b.id === id)
        if (!old) return addHelper(o, id, name, now)
        return { bots: o.bots.map(b => (b.id === id ? { ...b, name, spawnedAt: now } : b)) }
      })
    }

    return spawned
  })

  on('tool.call', async ($, e, next) => {
    await change($, e.agentId, b => ({ ...b, status: 'working', tool: e.tool, running: b.running + 1 }))
    try {
      const ran = await next(e)
      const isError = 'deny' in ran && !!ran.deny ? true : !!ran.isError
      await change($, e.agentId, b => {
        const running = Math.max(0, b.running - 1)
        if (isError) return { ...b, status: 'error', running }
        if (running > 0) return { ...b, running }
        return { ...b, status: b.status === 'idle' || b.status === 'done' ? b.status : 'thinking', tool: undefined, running }
      })
      return ran
    } catch (err) {
      await change($, e.agentId, b => ({ ...b, status: 'error', running: Math.max(0, b.running - 1) }))
      throw err
    }
  })

  // An ask means someone has to decide: the robot stands up and waves until the call ends.
  on('tool.check', async ($, e, next) => {
    const verdict = await next(e)
    if (verdict.decision === 'ask') await change($, e.agentId, b => ({ ...b, status: 'waiting' }))

    return verdict
  })

  on('turn.complete', async ($, e, next) => {
    const isError = e.reason === 'error' || e.reason === 'refusal'
    const isMain = !e.agentId
    await change($, e.agentId, b => ({
      ...b,
      status: isError ? 'error' : isMain ? 'idle' : 'done',
      tool: undefined,
      running: 0,
    }))

    return next(e)
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const els = $.ui.resolve(e)
    const { Box, Text } = els
    const { bots } = await read($, office)
    await read($, tick)
    const now = await $.clock.now()
    const list = [...bots].sort((a, b) => Number(b.isMain) - Number(a.isMain))
    const busy = list.filter(b => ['working', 'thinking'].includes(shown(b, now))).length
    const waiting = list.filter(b => shown(b, now) === 'waiting').length

    const summary =
      waiting > 0
        ? `${waiting} ta robot ruxsat kutyapti`
        : busy > 0
          ? `${busy} ta robot ishlayapti`
          : 'Hamma dam olyapti'

    const rows = list.map(b => {
      const st = shown(b, now)
      const tool = st === 'working' && b.tool ? ` · ${b.tool}` : ''
      const away = !b.isMain && b.slot < 0 ? ' (stol yo\'q)' : ''
      return (
        <Text dimColor={st === 'idle' || st === 'sleeping' || st === 'done'}>
          {b.isMain ? '◆' : '●'} {b.name} — {LABEL[st]}
          {tool}
          {away}
        </Text>
      )
    })

    if ('Svg' in els && els.Svg) {
      const Svg = els.Svg
      return (
        <Box flexDirection="column" gap={1}>
          <Text weight="semibold">{summary}</Text>
          <Svg source={drawOffice(list, now)} alt={`Ofis: ${summary}`} isInteractive />
          <Box flexDirection="column">{rows}</Box>
        </Box>
      )
    }

    return (
      <Box flexDirection="column">
        <Text bold>{summary}</Text>
        {rows}
      </Box>
    )
  })
}
