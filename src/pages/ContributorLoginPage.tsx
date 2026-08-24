import { Chrome, LogIn } from 'lucide-react'
import { Navigate, useSearchParams } from 'react-router-dom'
import { useState } from 'react'
import { Brand } from '../components/Brand'
import { safeReturnPath } from '../lib/navigation'
import { supabase } from '../lib/supabase'
import { useAuth } from '../providers/AuthProvider'

export function ContributorLoginPage(){const {session,profile}=useAuth();const [params]=useSearchParams();const [error,setError]=useState('');const returnTo=safeReturnPath(params.get('returnTo')||'/my-feedback');if(session&&profile)return <Navigate to={profile.role==='contributor'?returnTo:'/unauthorized'} replace/>;async function google(){setError('');const {error}=await supabase.auth.signInWithOAuth({provider:'google',options:{redirectTo:`${window.location.origin}${returnTo}`}});if(error)setError(error.message)}return <main className="grid min-h-screen place-items-center bg-[#f4f7f9] p-5"><div className="card w-full max-w-md p-8"><Brand/><p className="mt-8 text-sm font-bold uppercase tracking-wider text-[#ef5b32]">Contributor access</p><h1 className="mt-2 text-3xl font-black text-[#0b2940]">Share your event feedback.</h1><p className="mt-3 text-slate-600">Sign in to rate Exhibitors, leave comments and manage your submissions.</p>{error&&<p className="mt-5 rounded-xl bg-red-50 p-3 text-sm text-red-700" role="alert">{error}</p>}<button onClick={()=>void google()} className="btn-primary mt-8 w-full"><Chrome size={19}/>Continue with Google</button><p className="mt-5 flex items-center justify-center gap-2 text-xs text-slate-500"><LogIn size={14}/>Admin and Editor accounts cannot submit feedback.</p></div></main>}
