import { expect, mock, test } from 'claude-code/testing'

const PANE = {
  plugin: 'tokenkuzat',
  component: 'Pane',
  requestId: 'ofis',
  props: {
    title: 'Ofis',
    isFocused: false,
    bodyColumns: 60,
    placement: 'dock',
    scroll: { offset: 0, bodyRows: 30 },
    view: {},
  },
} as const

test('a helper the main agent spawns gets a desk and shows its tool', async ($, on) => {
  mock.clock(on, { now: 1_800_000_000_000 })
  on('command.register', () => ({ value: { command: 'ofis' } }))
  on('ui.open', () => ({ value: { isPlaced: true } }))
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  on('turn.start', (_, e) => ({ turnId: e.turnId }))
  on('agent.spawn', () => ({ model: 'claude-haiku-5-5', agentId: 'a1' }))
  // The tool runs until the test lets it finish, so the helper stays at work.
  let finish = () => {}
  on('tool.call', () => new Promise(r => (finish = () => r({ result: {} }))))

  await $.session.start({ cwd: '/', surface: 'desktop', isInteractive: true })
  await $.turn.start({ text: 'salom', turnId: 't1' })
  await $.agent.spawn({
    tool_use_id: 'tu1',
    prompt: 'fayllarni qidir',
    description: 'Qidiruvchi',
    subagentType: 'Explore',
    provider: { plugin: 'engine', tier: 'core' },
    parentModel: 'claude-opus-5-5',
    background: false,
    fork: false,
  })
  const call = $.tool.call({ tool: 'Grep', pattern: 'x', agentId: 'a1' } as never)
  for (let i = 0; i < 50; i++) await Promise.resolve()

  const ui = await $.ui.mount({ ...PANE, surface: 'desktop' })
  expect((await ui.find({ type: 'Text', text: /Qidiruvchi/ }))?.text).toBe('● Qidiruvchi — ishlayapti · Grep')
  expect((await ui.find({ type: 'Text', text: /Asosiy agent/ }))?.text).toBe("◆ Asosiy agent — o'ylayapti")
  expect(await ui.find({ type: 'Svg' })).toBeTruthy()
  await ui.unmount()

  finish()
  await call
  const after = await $.ui.mount({ ...PANE, surface: 'desktop' })
  expect((await after.find({ type: 'Text', text: /Qidiruvchi/ }))?.text).toBe("● Qidiruvchi — o'ylayapti")
  await after.unmount()
})

test('the terminal gets the list without a drawing', async ($, on) => {
  mock.clock(on, { now: 1_800_000_000_000 })
  on('command.register', () => ({ value: { command: 'ofis' } }))
  on('ui.open', () => ({ value: { isPlaced: true } }))
  on('session.start', (_, e) => ({ cwd: e.cwd }))

  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  const ui = await $.ui.mount({ ...PANE, surface: 'terminal' })
  expect((await ui.find({ type: 'Text', text: /Hamma/ }))?.text).toBe('Hamma dam olyapti')
  expect(await ui.find({ type: 'Svg' })).toBeFalsy()
  await ui.unmount()
})

test('an ask makes the robot wait, and the main turn ending sends it to rest', async ($, on) => {
  mock.clock(on, { now: 1_800_000_000_000 })
  on('command.register', () => ({ value: { command: 'ofis' } }))
  on('ui.open', () => ({ value: { isPlaced: true } }))
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  on('tool.check', () => ({ decision: 'ask' }))
  on('turn.complete', (_, e) => ({ text: e.answer }))

  await $.session.start({ cwd: '/', surface: 'desktop', isInteractive: true })
  await $.tool.check({ tool: 'Bash', input: { command: 'rm -rf build' } })
  let ui = await $.ui.mount({ ...PANE, surface: 'desktop' })
  expect((await ui.find({ type: 'Text', text: /Asosiy/ }))?.text).toBe('◆ Asosiy agent — ruxsat kutyapti')
  await ui.unmount()

  await $.turn.complete({ answer: 'ok', durationMs: 5, isAborted: false, turnId: 't1', reason: 'answer' })
  ui = await $.ui.mount({ ...PANE, surface: 'desktop' })
  expect((await ui.find({ type: 'Text', text: /Asosiy/ }))?.text).toBe('◆ Asosiy agent — dam olyapti')
  await ui.unmount()
})
