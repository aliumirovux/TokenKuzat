import type { Bot, Status } from '../types'

// Shown status: an idle robot falls asleep, a finished helper cools down to idle.
export type Shown = Status | 'sleeping'

export const SLEEP_AFTER = 5 * 60_000
export const DONE_FOR = 6_000
const CARD_FOR = 4_000

export function shown(b: Bot, now: number): Shown {
  if (b.status === 'done' && now - b.since < DONE_FOR) return 'done'
  if (b.status === 'idle' || b.status === 'done')
    return now - b.since > SLEEP_AFTER ? 'sleeping' : 'idle'
  return b.status
}

export const LABEL: Record<Shown, string> = {
  idle: "dam olyapti",
  thinking: "o'ylayapti",
  working: 'ishlayapti',
  waiting: 'ruxsat kutyapti',
  error: 'xato',
  done: 'tugatdi',
  sleeping: 'uxlayapti',
}

const EYE: Record<Shown, string> = {
  idle: '#cbd5e1',
  thinking: '#93c5fd',
  working: '#5eead4',
  waiting: '#facc15',
  error: '#f87171',
  done: '#86efac',
  sleeping: '#94a3b8',
}

export const COLORS = ['#7cc4ff', '#ffb86b', '#a78bfa', '#6ee7b7', '#f472b6', '#facc15']
export const MAIN_COLOR = '#e2e8f0'

type Spot = { x: number; y: number; s: number }
const MAIN: Spot = { x: 140, y: 168, s: 0.95 }
// Three desks along the back wall, three in front.
const SLOTS: Spot[] = [
  { x: 215, y: 168, s: 0.95 },
  { x: 290, y: 168, s: 0.95 },
  { x: 365, y: 168, s: 0.95 },
  { x: 190, y: 246, s: 1.05 },
  { x: 275, y: 246, s: 1.05 },
  { x: 360, y: 246, s: 1.05 },
]
const SOFA = { x: 14, y: 212 }
const SEATS = [40, 70, 100]

const esc = (t: string) =>
  t.replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c] ?? c)

export function glyph(tool?: string): string {
  if (!tool) return ''
  if (tool === 'Bash') return '>_'
  if (tool === 'Edit' || tool === 'Write' || tool === 'NotebookEdit') return '✎'
  if (tool === 'Read') return '≡'
  if (tool === 'Grep' || tool === 'Glob') return '⌕'
  if (tool.startsWith('Web')) return 'www'
  if (tool === 'Agent' || tool === 'Task') return '⇢'
  if (tool.startsWith('mcp__')) return '◆'
  return tool.slice(0, 2)
}

// Small hash so robots do not all blink together.
const phase = (id: string) => {
  let n = 0
  for (const c of id) n = (n * 31 + c.charCodeAt(0)) % 997
  return ((n % 40) / 10).toFixed(1)
}

function eyes(st: Shown, color: string, id: string): string {
  if (st === 'sleeping')
    return `<path d="M-7,-36 h5 M2,-36 h5" stroke="${color}" stroke-width="1.6" stroke-linecap="round"/>`
  if (st === 'error')
    return `<path d="M-7,-39 l4,4 M-3,-39 l-4,4 M3,-39 l4,4 M7,-39 l-4,4" stroke="${color}" stroke-width="1.4" stroke-linecap="round"/>`
  if (st === 'done')
    return `<path d="M-7,-35 l2.5,-2.5 l2.5,2.5 M2,-35 l2.5,-2.5 l2.5,2.5" stroke="${color}" stroke-width="1.4" fill="none" stroke-linecap="round"/>`
  const dx = st === 'working' ? 1.5 : 0
  const cy = st === 'working' ? -35.5 : -37
  const blink = `<animate attributeName="ry" values="2.4;2.4;0.3;2.4" keyTimes="0;0.92;0.96;1" dur="4s" begin="${phase(id)}s" repeatCount="indefinite"/>`
  return [-4, 4]
    .map(x => `<ellipse cx="${x + dx}" cy="${cy}" rx="2" ry="2.4" fill="${color}">${blink}</ellipse>`)
    .join('')
}

function arm(side: -1 | 1, color: string, st: Shown, isPointing: boolean): string {
  const x = side < 0 ? -15 : 10
  const limb = `<rect x="0" y="0" width="5" height="13" rx="2.5" fill="${color}" stroke="rgba(0,0,0,.18)" stroke-width=".6"/>`
  if (side > 0 && st === 'waiting')
    return `<g transform="translate(${x + 2.5},-24)"><g transform="rotate(-150)"><animateTransform attributeName="transform" type="rotate" values="-160;-115;-160" dur=".7s" repeatCount="indefinite"/><g transform="translate(-2.5,0)">${limb}</g></g></g>`
  if (side > 0 && isPointing)
    return `<g transform="translate(${x + 2.5},-22) rotate(-95)"><g transform="translate(-2.5,0)">${limb}</g></g>`
  const bob =
    st === 'working'
      ? `<animateTransform attributeName="transform" type="translate" values="${x} -24;${x} -26;${x} -24" dur=".36s" begin="${side > 0 ? '.18s' : '0s'}" repeatCount="indefinite"/>`
      : ''
  return `<g transform="translate(${x},-24)">${bob}${limb}</g>`
}

function robot(b: Bot, st: Shown): string {
  const c = b.color
  const eye = EYE[st]
  const isPointing = b.isMain && st === 'working' && (b.tool === 'Agent' || b.tool === 'Task')
  const parts: string[] = []

  if (st === 'thinking')
    parts.push(
      `<g transform="translate(15,-60)"><ellipse rx="11" ry="6.5" fill="#f8fafc" opacity=".92"/>` +
        [-5, 0, 5]
          .map(
            (x, i) =>
              `<circle cx="${x}" cy="0" r="1.4" fill="#334155"><animate attributeName="opacity" values=".2;1;.2" dur="1.2s" begin="${i * 0.2}s" repeatCount="indefinite"/></circle>`,
          )
          .join('') +
        `</g>`,
    )
  if (st === 'sleeping')
    parts.push(
      [0, 1.2]
        .map(
          d =>
            `<text x="12" y="-50" font-size="8" font-family="ui-rounded,system-ui" fill="#cbd5e1" opacity="0">z<animate attributeName="y" values="-48;-66" dur="2.4s" begin="${d}s" repeatCount="indefinite"/><animate attributeName="opacity" values="0;1;0" dur="2.4s" begin="${d}s" repeatCount="indefinite"/></text>`,
        )
        .join(''),
    )
  if (st === 'error')
    parts.push(`<text x="0" y="-58" font-size="11" font-weight="700" text-anchor="middle" fill="#f87171">!</text>`)

  const pulse = st === 'working' ? `<animate attributeName="opacity" values="1;.35;1" dur=".9s" repeatCount="indefinite"/>` : ''
  parts.push(
    `<line x1="0" y1="-46" x2="0" y2="-52" stroke="#8892a0" stroke-width="1.5"/>`,
    `<circle cx="0" cy="-53" r="2.2" fill="${eye}">${pulse}</circle>`,
    arm(-1, c, st, false),
    `<rect x="-10" y="-26" width="20" height="24" rx="6" fill="${c}"/>`,
    `<rect x="-3" y="-18" width="6" height="3" rx="1.5" fill="${eye}" opacity=".75"/>`,
    arm(1, c, st, isPointing),
    `<rect x="-12" y="-46" width="24" height="19" rx="6" fill="${c}"/>`,
    `<rect x="-9" y="-43" width="18" height="12" rx="3" fill="#0f141b"/>`,
    eyes(st, eye, b.id),
  )
  if (b.isMain)
    parts.push(
      `<path d="M-13,-38 a13,13 0 0 1 26,0" stroke="#334155" stroke-width="2.4" fill="none"/>`,
      `<rect x="-15.5" y="-41" width="4.5" height="8" rx="2" fill="#334155"/>`,
      `<rect x="11" y="-41" width="4.5" height="8" rx="2" fill="#334155"/>`,
      `<path d="M14,-34 q-2,6 -9,6" stroke="#334155" stroke-width="1.2" fill="none"/><circle cx="5" cy="-28" r="1.3" fill="#334155"/>`,
    )
  if (st === 'idle')
    parts.push(
      `<g transform="translate(16,-14)"><rect x="-3" y="0" width="7" height="7" rx="1.5" fill="#f8fafc"/><path d="M4,2 q3,1.5 0,3.5" stroke="#f8fafc" stroke-width="1" fill="none"/>` +
        `<path d="M0,-2 q-1.5,-3 0,-6" stroke="#e2e8f0" stroke-width=".8" fill="none" opacity="0"><animate attributeName="opacity" values="0;.8;0" dur="2.6s" repeatCount="indefinite"/></path></g>`,
    )

  const turn = st === 'error' ? ' rotate(-9)' : ''
  return `<g transform="translate(0,0)${turn}"><title>${esc(b.name)} — ${LABEL[st]}${b.tool && st === 'working' ? ' · ' + esc(b.tool) : ''}</title>${parts.join('')}</g>`
}

function desk(b: Bot | undefined, st: Shown | undefined, sp: Spot, atDesk: boolean): string {
  const isWorking = atDesk && st === 'working'
  const g = isWorking && b ? glyph(b.tool) : ''
  const screen = isWorking ? '#0b3b3a' : '#1f2937'
  const out: string[] = []
  if (st === 'waiting' && atDesk)
    out.push(
      `<rect x="-36" y="-66" width="72" height="100" rx="9" fill="none" stroke="#facc15" stroke-width="1.4" stroke-dasharray="5 4"><animate attributeName="stroke-dashoffset" values="0;18" dur="1s" repeatCount="indefinite"/></rect>`,
    )
  if (b && atDesk) {
    const lift = st === 'waiting' ? -10 : 2
    out.push(`<g transform="translate(-10,${lift})">${robot(b, st ?? 'idle')}</g>`)
  }
  out.push(
    `<rect x="9" y="-5" width="3" height="5" fill="#475569"/>`,
    `<rect x="-1" y="-21" width="24" height="16" rx="2" fill="${screen}" stroke="#475569" stroke-width="1"/>`,
  )
  if (g)
    out.push(
      `<text x="11" y="-10" font-size="7.5" font-family="ui-monospace,Menlo,monospace" text-anchor="middle" fill="#5eead4">${esc(g)}<animate attributeName="opacity" values="1;.55;1" dur="1.4s" repeatCount="indefinite"/></text>`,
    )
  out.push(
    `<rect x="-28" y="0" width="56" height="6" rx="1.5" fill="#8a6a4b"/>`,
    `<rect x="-28" y="6" width="56" height="3" fill="#6e533a"/>`,
    `<rect x="-25" y="9" width="3" height="13" fill="#5b4632"/><rect x="22" y="9" width="3" height="13" fill="#5b4632"/>`,
  )
  if (b) {
    const name = b.name.length > 14 ? b.name.slice(0, 13) + '…' : b.name
    out.push(
      `<text x="0" y="31" font-size="7" font-family="ui-rounded,system-ui" text-anchor="middle" fill="#94a3b8">${esc(name)}</text>`,
    )
  }
  return `<g transform="translate(${sp.x},${sp.y}) scale(${sp.s})">${out.join('')}</g>`
}

// An empty desk slot becomes a small garden.
function garden(sp: Spot): string {
  return (
    `<g transform="translate(${sp.x},${sp.y + 14}) scale(${sp.s})">` +
    `<ellipse cx="0" cy="6" rx="22" ry="4" fill="#2f3a2f" opacity=".6"/>` +
    `<path d="M-8,4 h16 l-2,6 h-12 z" fill="#a16207"/>` +
    `<path d="M0,4 q-10,-10 -6,-20 M0,4 q2,-14 9,-18 M0,4 q-1,-8 1,-24" stroke="#4ade80" stroke-width="2.2" fill="none" stroke-linecap="round"/>` +
    `<circle cx="-12" cy="2" r="2" fill="#f472b6"/><circle cx="13" cy="3" r="1.8" fill="#fbbf24"/>` +
    `</g>`
  )
}

function card(from: { x: number; y: number }, to: { x: number; y: number }, mark: string, ink: string): string {
  const mx = (from.x + to.x) / 2
  const my = Math.min(from.y, to.y) - 40
  return (
    `<g opacity="0"><set attributeName="opacity" to="1" begin="0s"/>` +
    `<rect x="-7" y="-5" width="14" height="10" rx="1.6" fill="#fef3c7" stroke="#b45309" stroke-width=".7"/>` +
    `<text x="0" y="2.6" font-size="7" text-anchor="middle" fill="${ink}">${mark}</text>` +
    `<animateMotion dur="1.3s" fill="freeze" path="M${from.x},${from.y} Q${mx},${my} ${to.x},${to.y}"/>` +
    `<animate attributeName="opacity" values="1;1;0" keyTimes="0;.8;1" dur="1.8s" fill="freeze"/>` +
    `</g>`
  )
}

function sofa(sitters: { b: Bot; st: Shown }[]): string {
  const { x, y } = SOFA
  const people = sitters
    .map((p, i) => `<g transform="translate(${x + (SEATS[i] ?? 0)},${y + 24}) scale(.9)">${robot(p.b, p.st)}</g>`)
    .join('')
  return (
    `<rect x="${x}" y="${y}" width="112" height="24" rx="8" fill="#43536f"/>` +
    people +
    `<rect x="${x}" y="${y + 18}" width="112" height="14" rx="5" fill="#536684"/>` +
    `<rect x="${x - 7}" y="${y + 7}" width="13" height="27" rx="5" fill="#3d4c66"/>` +
    `<rect x="${x + 106}" y="${y + 7}" width="13" height="27" rx="5" fill="#3d4c66"/>` +
    `<rect x="${x + 4}" y="${y + 32}" width="4" height="6" fill="#2a3346"/><rect x="${x + 104}" y="${y + 32}" width="4" height="6" fill="#2a3346"/>`
  )
}

function drone(target?: { x: number; y: number }): string {
  const body =
    `<ellipse cx="0" cy="0" rx="11" ry="4" fill="#cbd5e1"/><circle cx="0" cy="1" r="2" fill="#38bdf8"/>` +
    [-1, 1]
      .map(
        s =>
          `<line x1="${s * 6}" y1="-3" x2="${s * 6}" y2="-6" stroke="#94a3b8" stroke-width="1"/>` +
          `<ellipse cx="${s * 6}" cy="-6.5" rx="6" ry="1" fill="#94a3b8"><animate attributeName="rx" values="6;1.5;6" dur=".18s" repeatCount="indefinite"/></ellipse>`,
      )
      .join('')
  if (!target)
    return `<g><animateTransform attributeName="transform" type="translate" values="70 22;330 30;200 18;70 22" dur="18s" repeatCount="indefinite"/>${body}</g>`
  const dx = target.x
  const dy = target.y - 88
  return (
    `<polygon points="${dx - 3},${dy + 4} ${dx + 3},${dy + 4} ${dx + 26},${target.y - 6} ${dx - 26},${target.y - 6}" fill="#facc15" opacity=".16"><animate attributeName="opacity" values=".1;.24;.1" dur="1.4s" repeatCount="indefinite"/></polygon>` +
    `<g transform="translate(${dx},${dy})"><animateTransform attributeName="transform" type="translate" values="${dx} ${dy};${dx} ${dy - 3};${dx} ${dy}" dur="1.6s" repeatCount="indefinite"/>${body}</g>`
  )
}

function room(): string {
  return (
    `<defs><linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#1e3a5f"/><stop offset="1" stop-color="#4f86c6"/></linearGradient>` +
    `<clipPath id="win"><rect x="22" y="22" width="86" height="58" rx="3"/></clipPath></defs>` +
    `<rect width="400" height="285" fill="#262b36"/>` +
    `<rect y="140" width="400" height="145" fill="#353b48"/>` +
    [172, 210, 252].map(y => `<line x1="0" y1="${y}" x2="400" y2="${y}" stroke="#2e3440" stroke-width="1"/>`).join('') +
    `<rect y="136" width="400" height="5" fill="#1f232c"/>` +
    // window with drifting clouds
    `<rect x="18" y="18" width="94" height="66" rx="5" fill="#3f4656"/>` +
    `<g clip-path="url(#win)"><rect x="22" y="22" width="86" height="58" fill="url(#sky)"/>` +
    `<g opacity=".85"><animateTransform attributeName="transform" type="translate" values="-30 0;90 0" dur="40s" repeatCount="indefinite"/>` +
    `<ellipse cx="40" cy="40" rx="12" ry="5" fill="#e2e8f0"/><ellipse cx="48" cy="37" rx="8" ry="5" fill="#e2e8f0"/></g>` +
    `<g opacity=".6"><animateTransform attributeName="transform" type="translate" values="40 0;-60 0" dur="55s" repeatCount="indefinite"/>` +
    `<ellipse cx="70" cy="62" rx="10" ry="4" fill="#e2e8f0"/></g></g>` +
    `<line x1="65" y1="22" x2="65" y2="80" stroke="#3f4656" stroke-width="3"/>` +
    // wall clock
    `<g transform="translate(160,46)"><circle r="13" fill="#f1f5f9"/><circle r="13" fill="none" stroke="#475569" stroke-width="2"/>` +
    `<line x1="0" y1="0" x2="0" y2="-7" stroke="#334155" stroke-width="1.6" stroke-linecap="round"><animateTransform attributeName="transform" type="rotate" values="0;360" dur="3600s" repeatCount="indefinite"/></line>` +
    `<line x1="0" y1="0" x2="0" y2="-10" stroke="#ef4444" stroke-width=".8"><animateTransform attributeName="transform" type="rotate" values="0;360" dur="60s" repeatCount="indefinite"/></line></g>` +
    // shelf with books and a plant
    `<rect x="250" y="62" width="110" height="4" rx="1" fill="#6e533a"/>` +
    [['#60a5fa', 256, 18], ['#f59e0b', 263, 22], ['#a78bfa', 271, 16], ['#34d399', 278, 20], ['#f87171', 286, 17]]
      .map(([c, x, hh]) => `<rect x="${x}" y="${62 - Number(hh)}" width="6" height="${hh}" rx="1" fill="${c}"/>`)
      .join('') +
    `<path d="M336,62 h12 l-2,-8 h-8 z" fill="#a16207"/><path d="M342,54 q-8,-8 -5,-16 M342,54 q4,-10 9,-12 M342,54 q0,-8 1,-18" stroke="#4ade80" stroke-width="2" fill="none" stroke-linecap="round"/>`
  )
}

export function drawOffice(bots: Bot[], now: number): string {
  const main = bots.find(b => b.isMain)
  const helpers = bots.filter(b => !b.isMain && b.slot >= 0 && b.slot < SLOTS.length)
  const st = new Map(bots.map(b => [b.id, shown(b, now)] as const))

  // Idle and sleeping robots take the sofa, the main agent first.
  const resting = [main, ...helpers].filter(
    (b): b is Bot => !!b && (st.get(b.id) === 'idle' || st.get(b.id) === 'sleeping'),
  )
  const onSofa = new Set(resting.slice(0, SEATS.length).map(b => b.id))

  const spotOf = (b: Bot): Spot => (b.isMain ? MAIN : SLOTS[b.slot] ?? MAIN)
  const head = (b: Bot) => {
    const sp = spotOf(b)
    return { x: sp.x - 10 * sp.s, y: sp.y - 30 * sp.s }
  }

  const deskFor = (sp: Spot, b?: Bot) => desk(b, b && st.get(b.id), sp, !!b && !onSofa.has(b.id))
  const bySlot = new Map(helpers.map(b => [b.slot, b] as const))
  const slotDraw = (i: number) => {
    const b = bySlot.get(i)
    const sp = SLOTS[i] ?? MAIN
    return b ? deskFor(sp, b) : garden(sp)
  }

  const cards: string[] = []
  if (main)
    for (const b of helpers) {
      if (now - b.spawnedAt < CARD_FOR) cards.push(card(head(main), head(b), '≡', '#92400e'))
      if (st.get(b.id) === 'done') cards.push(card(head(b), head(main), '✓', '#15803d'))
    }

  const alarm = [main, ...helpers].find(
    (b): b is Bot => !!b && (st.get(b.id) === 'waiting' || st.get(b.id) === 'error'),
  )
  const sitters = resting.slice(0, SEATS.length).map(b => ({ b, st: st.get(b.id) ?? 'idle' }))

  return (
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 285" width="400" height="285" style="border-radius:12px">` +
    room() +
    (main ? deskFor(MAIN, main) : '') +
    [0, 1, 2].map(slotDraw).join('') +
    sofa(sitters) +
    [3, 4, 5].map(slotDraw).join('') +
    cards.join('') +
    drone(alarm ? head(alarm) : undefined) +
    `</svg>`
  )
}
