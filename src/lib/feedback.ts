export const MAX_COMMENTS_PER_EXHIBITOR = 5

export function validateFeedbackSubmission(
  rating: number,
  comment: string,
  commentCount: number,
) {
  const hasComment = comment.trim().length > 0
  if (!rating && !hasComment) return 'Select a rating or enter a comment.'
  if (hasComment && commentCount >= MAX_COMMENTS_PER_EXHIBITOR) {
    return `You can post at most ${MAX_COMMENTS_PER_EXHIBITOR} comments for this Exhibitor.`
  }
  return null
}
