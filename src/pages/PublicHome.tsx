import { ArrowRight, CalendarDays, MapPin } from 'lucide-react'
import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { Brand } from '../components/Brand'
import { supabase } from '../lib/supabase'
import { useAuth } from '../providers/AuthProvider'

type PublicEvent = { event_id:string; name:string; slug:string; location:string; asset_path:string|null; start_at:string }

export function PublicHome() {
  const { profile } = useAuth(); const [events,setEvents]=useState<PublicEvent[]>([]); const [loading,setLoading]=useState(true); const [error,setError]=useState('')
  useEffect(()=>{ void (async()=>{ const {data,error}=await supabase.rpc('public_list_visible_events'); if(error)setError('Events could not be loaded. Please try again.'); else setEvents((data??[]) as PublicEvent[]); setLoading(false) })() },[])
  return <main className="min-h-screen bg-[#f4f7f9]">
    <header className="border-b border-slate-200 bg-white"><div className="mx-auto flex max-w-7xl items-center justify-between px-5 py-4"><Brand /><div className="flex gap-2">{profile?.role==='contributor'&&<><Link className="btn-secondary" to="/advertising">Advertise</Link><Link className="btn-secondary" to="/my-feedback">My feedback</Link></>}<Link className="btn-secondary" to={profile && ['admin','editor'].includes(profile.role) ? '/manage' : profile?.role==='contributor'?'/profile':'/contributor/login'}>{profile?profile.role==='contributor'?'Profile':'Management':'Sign in'}<ArrowRight size={17} /></Link></div></div></header>
    <section className="mx-auto max-w-7xl px-5 py-14 md:py-20"><span className="text-sm font-black uppercase tracking-[.2em] text-[#ef5b32]">Discover what matters</span><h1 className="mt-4 max-w-3xl text-4xl font-black tracking-tight text-[#0b2940] md:text-6xl">Find the people and ideas shaping your event.</h1><p className="mt-5 max-w-2xl text-lg leading-8 text-slate-600">Browse exhibitors, locate booths and share thoughtful feedback—all from your phone.</p>
      <h2 className="mt-12 text-2xl font-black text-slate-900">Available events</h2>
      {loading && <p className="mt-5 text-slate-500">Loading events…</p>}{error && <div className="card mt-5 p-5 text-red-700">{error}</div>}
      {!loading&&!error&&events.length===0&&<div className="card mt-5 p-8 text-center"><CalendarDays className="mx-auto text-[#ef5b32]"/><h3 className="mt-3 text-xl font-bold">No public events yet</h3><p className="mt-2 text-slate-500">Visible events will appear here once the Admin publishes them.</p></div>}
      <div className="mt-5 grid gap-5 md:grid-cols-2 lg:grid-cols-3">{events.map(event=><Link key={event.event_id} to={`/e/${event.slug}`} className="card group overflow-hidden transition hover:-translate-y-1 hover:shadow-lg">{event.asset_path?<img className="h-40 w-full object-cover" src={event.asset_path} alt=""/>:<div className="h-28 bg-gradient-to-br from-[#0b2940] to-[#28516d]"/>}<div className="p-5"><h3 className="text-xl font-black text-slate-900">{event.name}</h3><p className="mt-3 flex gap-2 text-sm text-slate-600"><CalendarDays size={17}/>{new Date(event.start_at).toLocaleDateString(undefined,{dateStyle:'medium'})}</p><p className="mt-2 flex gap-2 text-sm text-slate-600"><MapPin size={17}/>{event.location}</p><span className="mt-5 inline-flex items-center gap-2 font-bold text-[#ef5b32]">Explore exhibitors <ArrowRight size={17}/></span></div></Link>)}</div>
    </section>
  </main>
}
