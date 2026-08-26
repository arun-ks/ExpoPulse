import { Save, Star } from 'lucide-react'
import { useCallback, useEffect, useState, type FormEvent } from 'react'
import { Link } from 'react-router-dom'
import {
  MAX_COMMENTS_PER_EXHIBITOR,
  validateFeedbackSubmission,
} from '../lib/feedback'
import { supabase } from '../lib/supabase'
import { useAuth } from '../providers/AuthProvider'

type Feedback = {
  rating: number | null
  comment_count: number
  can_submit: boolean
  lock_at: string
}

export function FeedbackPanel({
  slug,
  publicId,
  onSaved,
}: {
  slug: string
  publicId: string
  onSaved?: () => void
}) {
  const { session, profile } = useAuth()
  const [feedback, setFeedback] = useState<Feedback | null>(null)
  const [rating, setRating] = useState(0)
  const [comment, setComment] = useState('')
  const [anonymous, setAnonymous] = useState(false)
  const [busy, setBusy] = useState(false)
  const [message, setMessage] = useState('')

  const load = useCallback(async () => {
    if (profile?.role !== 'contributor') return
    const { data } = await supabase.rpc('contributor_get_feedback_v2', {
      p_event_slug: slug,
      p_public_id: publicId,
    })
    const item = data as Feedback | null
    setFeedback(item)
    setRating(item?.rating ?? 0)
  }, [profile?.role, publicId, slug])

  useEffect(() => {
    void load()
  }, [load])

  if (!session) {
    return (
      <section className="mt-8 border-t pt-7">
        <h2 className="text-xl font-black">Share feedback</h2>
        <p className="mt-2 text-slate-600">
          Sign in as a Contributor to rate this Exhibitor &amp; leave comment.
        </p>
        <Link
          className="btn-primary mt-4"
          to={`/contributor/login?returnTo=${encodeURIComponent(`/e/${slug}/exhibitors/${publicId}`)}`}
        >
          Contributor sign in
        </Link>
      </section>
    )
  }
  if (profile?.role !== 'contributor') return null
  if (feedback && !feedback.can_submit) {
    return (
      <section className="mt-8 border-t pt-7">
        <h2 className="text-xl font-black">Feedback closed</h2>
        <p className="mt-2 text-slate-600">
          The submission window for this Event has ended.
        </p>
      </section>
    )
  }

  const commentCount = Number(feedback?.comment_count ?? 0)
  const commentsRemaining = Math.max(
    0,
    MAX_COMMENTS_PER_EXHIBITOR - commentCount,
  )

  async function submit(event: FormEvent) {
    event.preventDefault()
    const validationMessage = validateFeedbackSubmission(
      rating,
      comment,
      commentCount,
    )
    if (validationMessage) {
      setMessage(validationMessage)
      return
    }

    setBusy(true)
    setMessage('')
    const hasComment = comment.trim().length > 0
    const { error } = await supabase.rpc('contributor_submit_feedback', {
      p_event_slug: slug,
      p_public_id: publicId,
      p_rating: rating || null,
      p_comment: comment,
      p_anonymous: anonymous,
    })

    if (error) {
      setMessage(error.message)
    } else {
      setComment('')
      setAnonymous(false)
      setMessage(hasComment ? 'Feedback and comment saved.' : 'Rating saved.')
      await load()
      onSaved?.()
    }
    setBusy(false)
  }

  const success =
    message === 'Feedback and comment saved.' || message === 'Rating saved.'

  return (
    <section className="mt-8 border-t pt-7">
      <h2 className="text-xl font-black">Your feedback</h2>
      <form className="mt-4" onSubmit={submit}>
        <fieldset>
          <legend className="label">Rating</legend>
          <p className="mt-1 text-sm text-slate-500">
            One rating per Exhibitor. You can update it while feedback is open.
          </p>
          <div className="mt-2 flex gap-2">
            {[1, 2, 3, 4, 5].map((value) => (
              <button
                type="button"
                aria-label={`${value} star${value === 1 ? '' : 's'}`}
                onClick={() => setRating(value)}
                key={value}
              >
                <Star
                  size={30}
                  className={
                    value <= rating
                      ? 'fill-amber-400 text-amber-400'
                      : 'text-slate-300'
                  }
                />
              </button>
            ))}
          </div>
        </fieldset>
        <label className="mt-5 block">
          <span className="label">
            Add a comment{' '}
            <span className="font-normal text-slate-400">(optional)</span>
          </span>
          <textarea
            className="field min-h-24"
            maxLength={200}
            disabled={commentsRemaining === 0}
            value={comment}
            onChange={(event) => setComment(event.target.value)}
          />
          <span className="mt-1 flex justify-between text-xs text-slate-400">
            <span>
              {commentsRemaining
                ? `${commentsRemaining} of 5 comments remaining for this Exhibitor`
                : 'Maximum of 5 comments reached for this Exhibitor'}
            </span>
            <span>{comment.length}/200</span>
          </span>
        </label>
        <label className="mt-3 flex items-center gap-2 text-sm text-slate-600">
          <input
            type="checkbox"
            disabled={commentsRemaining === 0}
            checked={anonymous}
            onChange={(event) => setAnonymous(event.target.checked)}
          />
          Display this comment anonymously
        </label>
        {message && (
          <p
            className={`mt-3 text-sm ${success ? 'text-emerald-700' : 'text-red-700'}`}
          >
            {message}
          </p>
        )}
        <button className="btn-primary mt-4" disabled={busy}>
          <Save size={17} />
          {busy ? 'Saving…' : 'Save feedback'}
        </button>
      </form>
    </section>
  )
}
