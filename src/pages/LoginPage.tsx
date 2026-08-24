import { Activity, ArrowRight, LockKeyhole } from 'lucide-react'
import { useState, type FormEvent } from 'react'
import { Navigate, useSearchParams } from 'react-router-dom'
import { Brand } from '../components/Brand'
import { safeReturnPath } from '../lib/navigation'
import { supabase } from '../lib/supabase'
import { useAuth } from '../providers/AuthProvider'

export function LoginPage() {
  const { session, profile } = useAuth()
  const [params] = useSearchParams()
  const returnTo = safeReturnPath(params.get('returnTo'))
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [busy, setBusy] = useState(false)

  if (session && profile) return <Navigate to={returnTo} replace />

  const submit = async (event: FormEvent) => {
    event.preventDefault(); setBusy(true); setError('')
    const { error: signInError } = await supabase.auth.signInWithPassword({ email, password })
    if (signInError) setError(signInError.message)
    setBusy(false)
  }

  return <main className="grid min-h-screen bg-[#f4f7f9] lg:grid-cols-2">
    <section className="flex items-center justify-center p-6 md:p-12"><div className="w-full max-w-md">
      <Brand />
      <div className="mt-12"><span className="inline-flex items-center gap-2 rounded-full bg-orange-50 px-3 py-1.5 text-xs font-bold uppercase tracking-wider text-[#d94722]"><LockKeyhole size={14} />Administration</span><h1 className="mt-5 text-4xl font-black tracking-tight text-[#0b2940]">Welcome back.</h1><p className="mt-3 text-slate-600">Sign in to manage events, exhibitors and community safety.</p></div>
      <form onSubmit={submit} className="mt-8 space-y-5">
        <label className="block"><span className="label">Email address</span><input className="field" type="email" autoComplete="email" required value={email} onChange={e => setEmail(e.target.value)} /></label>
        <label className="block"><span className="label">Password</span><input className="field" type="password" autoComplete="current-password" required value={password} onChange={e => setPassword(e.target.value)} /></label>
        {error && <p className="rounded-xl bg-red-50 p-3 text-sm font-medium text-red-700" role="alert">{error}</p>}
        <button disabled={busy} className="btn-primary w-full">{busy ? 'Signing in…' : 'Sign in'}<ArrowRight size={18} /></button>
      </form>
      <p className="mt-7 text-center text-xs leading-5 text-slate-500">Access is limited to authorized ExpoPulse administrators and editors.</p>
    </div></section>
    <section className="relative hidden overflow-hidden bg-[#0b2940] lg:block"><div className="absolute -right-24 -top-24 size-96 rounded-full border-[60px] border-white/5" /><div className="absolute -bottom-36 -left-20 size-[34rem] rounded-full border-[80px] border-[#ef5b32]/20" /><div className="relative flex h-full flex-col justify-between p-16 text-white"><Activity size={36} className="text-[#ef5b32]" /><div><p className="max-w-lg text-4xl font-black leading-tight">Every exhibitor.<br />Every insight.<br /><span className="text-[#ff8b69]">One pulse.</span></p><p className="mt-6 max-w-md text-lg leading-8 text-slate-300">A focused workspace for keeping event information accurate and visitor conversations safe.</p></div><p className="text-sm text-slate-400">ExpoPulse management console</p></div></section>
  </main>
}
