import { Chrome, Linkedin, LoaderCircle, LogIn } from 'lucide-react'
import { Navigate, useSearchParams } from 'react-router-dom'
import { useState } from 'react'
import { Brand } from '../components/Brand'
import {
  contributorOAuthErrorMessage,
  contributorOAuthProviderKey,
  isContributorOAuthProvider,
  type ContributorOAuthProvider,
} from '../lib/contributorOAuth'
import { safeReturnPath } from '../lib/navigation'
import { supabase } from '../lib/supabase'
import { useAuth } from '../providers/AuthProvider'

function storedOAuthProvider() {
  try {
    const value = window.sessionStorage.getItem(contributorOAuthProviderKey)
    return isContributorOAuthProvider(value) ? value : null
  } catch {
    return null
  }
}

export function ContributorLoginPage() {
  const { session, profile } = useAuth()
  const [params] = useSearchParams()
  const returnedError = params.get('error_description') || params.get('error') || ''
  const [error, setError] = useState(() => contributorOAuthErrorMessage(returnedError, storedOAuthProvider()))
  const [pendingProvider, setPendingProvider] = useState<ContributorOAuthProvider | null>(null)
  const returnTo = safeReturnPath(params.get('returnTo') || '/my-feedback')

  if (session && profile) {
    return <Navigate to={profile.role === 'contributor' ? returnTo : '/unauthorized'} replace />
  }

  async function signIn(provider: ContributorOAuthProvider) {
    setError('')
    setPendingProvider(provider)
    try {
      window.sessionStorage.setItem(contributorOAuthProviderKey, provider)
    } catch {
      // OAuth still works when session storage is unavailable.
    }
    const callbackUrl = new URL('/contributor/login', window.location.origin)
    callbackUrl.searchParams.set('returnTo', returnTo)
    const { error: signInError } = await supabase.auth.signInWithOAuth({
      provider,
      options: { redirectTo: callbackUrl.toString() },
    })
    if (signInError) {
      setError(contributorOAuthErrorMessage(signInError.message, provider))
      setPendingProvider(null)
    }
  }

  const isPending = pendingProvider !== null

  return (
    <main className="grid min-h-screen place-items-center bg-[#f4f7f9] p-5">
      <div className="card w-full max-w-md p-8">
        <Brand />
        <p className="mt-8 text-sm font-bold uppercase tracking-wider text-[#ef5b32]">Contributor access</p>
        <h1 className="mt-2 text-3xl font-black text-[#0b2940]">Share your event feedback.</h1>
        <p className="mt-3 text-slate-600">Sign in to rate Exhibitors, leave comments and manage your submissions.</p>
        {error && <p className="mt-5 rounded-xl bg-red-50 p-3 text-sm text-red-700" role="alert">{error}</p>}
        <div className="mt-8 space-y-3">
          <button disabled={isPending} onClick={() => void signIn('google')} className="btn-primary w-full">
            {pendingProvider === 'google' ? <LoaderCircle className="animate-spin" size={19} /> : <Chrome size={19} />}
            Continue with Google
          </button>
          <button disabled={isPending} onClick={() => void signIn('linkedin_oidc')} className="btn-secondary w-full">
            {pendingProvider === 'linkedin_oidc' ? <LoaderCircle className="animate-spin" size={19} /> : <Linkedin size={19} />}
            Continue with LinkedIn
          </button>
        </div>
        <p className="mt-5 flex items-center justify-center gap-2 text-xs text-slate-500">
          <LogIn size={14} />Admin and Editor accounts cannot submit feedback.
        </p>
      </div>
    </main>
  )
}
