import { describe, expect, it } from 'vitest'
import { eventFormDefaults, eventSlug } from './events'

describe('eventSlug', () => {
  it('creates a safe readable slug', () => expect(eventSlug('  Tech Expo 2026! ')).toBe('tech-expo-2026'))
  it('removes accents and separators', () => expect(eventSlug('Café & Food')).toBe('cafe-food'))
})

describe('eventFormDefaults', () => {
  it('places lock seven days after end and visibility seven days after lock', () => {
    const values = eventFormDefaults(new Date('2026-08-25T01:00:00Z'))
    expect((new Date(values.lock).getTime() - new Date(values.end).getTime()) / 86_400_000).toBe(7)
    expect((new Date(values.visibleUntil).getTime() - new Date(values.lock).getTime()) / 86_400_000).toBe(7)
  })
})
