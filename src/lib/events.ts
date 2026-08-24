export function eventSlug(value: string) {
  return value.normalize('NFKD').replace(/[\u0300-\u036f]/g, '').toLowerCase().trim().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '')
}

export function localInputValue(date: Date) {
  const shifted = new Date(date.getTime() - date.getTimezoneOffset() * 60_000)
  return shifted.toISOString().slice(0, 16)
}

export function eventFormDefaults(now = new Date()) {
  const start = new Date(now); start.setDate(start.getDate() + 1); start.setHours(9, 0, 0, 0)
  const end = new Date(start); end.setHours(17, 0, 0, 0)
  const lock = new Date(end); lock.setDate(lock.getDate() + 7)
  const visibleUntil = new Date(lock); visibleUntil.setDate(visibleUntil.getDate() + 7)
  return { start: localInputValue(start), end: localInputValue(end), lock: localInputValue(lock), visibleUntil: localInputValue(visibleUntil) }
}

export function isoToEventLocal(iso: string, timeZone: string) {
  const parts = new Intl.DateTimeFormat('en-CA', { timeZone, year:'numeric', month:'2-digit', day:'2-digit', hour:'2-digit', minute:'2-digit', hourCycle:'h23' }).formatToParts(new Date(iso))
  const part = (type: Intl.DateTimeFormatPartTypes) => parts.find(item => item.type === type)?.value ?? ''
  return `${part('year')}-${part('month')}-${part('day')}T${part('hour')}:${part('minute')}`
}

