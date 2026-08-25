import { describe, expect, it } from 'vitest'
import { contributorOAuthErrorMessage, isContributorOAuthProvider } from './contributorOAuth'

describe('contributorOAuthErrorMessage', () => {
  it('directs a rate-limited Google user to LinkedIn', () => {
    expect(contributorOAuthErrorMessage('Daily quota exceeded', 'google')).toBe(
      'Google sign-in has reached its daily limit. Please continue with LinkedIn instead.',
    )
  })

  it('directs a rate-limited LinkedIn user to Google', () => {
    expect(contributorOAuthErrorMessage('Too many requests', 'linkedin_oidc')).toBe(
      'LinkedIn sign-in has reached its daily limit. Please continue with Google instead.',
    )
  })

  it('preserves errors unrelated to provider limits', () => {
    expect(contributorOAuthErrorMessage('Access denied', 'google')).toBe('Access denied')
  })
})

describe('isContributorOAuthProvider', () => {
  it('only accepts enabled contributor providers', () => {
    expect(isContributorOAuthProvider('google')).toBe(true)
    expect(isContributorOAuthProvider('linkedin_oidc')).toBe(true)
    expect(isContributorOAuthProvider('github')).toBe(false)
  })
})
