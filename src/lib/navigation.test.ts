import { describe, expect, it } from 'vitest'
import { safeReturnPath } from './navigation'

describe('safeReturnPath', () => {
  it('keeps local application paths', () => {
    expect(safeReturnPath('/manage/events?status=active')).toBe('/manage/events?status=active')
  })

  it('rejects protocol-relative and external paths', () => {
    expect(safeReturnPath('//evil.example/path')).toBe('/manage')
    expect(safeReturnPath('https://evil.example/path')).toBe('/manage')
  })
})

