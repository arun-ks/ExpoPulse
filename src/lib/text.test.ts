import { describe, expect, it } from 'vitest'
import { companyInitials } from './text'

describe('companyInitials', () => {
  it('ignores parenthesis and punctuation', () => expect(companyInitials('AI3D (S) SDN BHD')).toBe('AS'))
  it('discards punctuation-only words', () => expect(companyInitials('EVENESIS - EVENT TECHNOLOGY')).toBe('EE'))
  it('uses two characters for one-word names', () => expect(companyInitials('Microsoft')).toBe('MI'))
  it('supports names beginning with a number', () => expect(companyInitials('3M Malaysia')).toBe('3M'))
  it('has a safe fallback', () => expect(companyInitials('---')).toBe('?'))
})
