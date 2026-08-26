import { describe, expect, it } from 'vitest'
import { MAX_COMMENTS_PER_EXHIBITOR, validateFeedbackSubmission } from './feedback'

describe('feedback submission limits', () => {
  it('allows a rating without a comment', () => {
    expect(validateFeedbackSubmission(4, '', MAX_COMMENTS_PER_EXHIBITOR)).toBeNull()
  })

  it('allows comments until the fifth comment', () => {
    expect(validateFeedbackSubmission(0, 'Useful demo', 4)).toBeNull()
  })

  it('blocks a sixth comment for the same Exhibitor', () => {
    expect(validateFeedbackSubmission(0, 'One more', 5)).toBe(
      'You can post at most 5 comments for this Exhibitor.',
    )
  })

  it('requires at least a rating or a comment', () => {
    expect(validateFeedbackSubmission(0, '  ', 0)).toBe(
      'Select a rating or enter a comment.',
    )
  })
})
