import { ArrowLeft, CalendarDays, Clock3, Edit3, ExternalLink, MapPin } from 'lucide-react'
import { useEffect, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import type { EventSummary } from '../types'

export function EventDetailPage() {
  const { eventId } = useParams(); const [item,setItem]=useState<EventSummary|null>(null); const [error,setError]=useState('')
  useEffect(()=>{ if(eventId) void supabase.rpc('manage_get_event',{p_event_id:eventId}).then(({data,error})=>{if(error)setError(error.message);else setItem(data?.[0] as EventSummary)}) },[eventId])
  if(error) return <p className="rounded-xl bg-red-50 p-4 text-red-700">{error}</p>
  if(!item) return <p className="p-10 text-center text-slate-500">Loading Event…</p>
  const date=(value:string)=>new Intl.DateTimeFormat('en-SG',{dateStyle:'medium',timeStyle:'short',timeZone:item.timezone}).format(new Date(value))
  return <><Link to="/manage/events" className="inline-flex items-center gap-2 text-sm font-semibold text-slate-500 hover:text-slate-900"><ArrowLeft size={17}/>All Events</Link><div className="mt-5 flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between"><div><div className="flex items-center gap-2"><span className={`rounded-full px-3 py-1 text-xs font-black uppercase ${item.status==='active'?'bg-emerald-50 text-emerald-700':item.status==='draft'?'bg-amber-50 text-amber-700':'bg-slate-100 text-slate-600'}`}>{item.status}</span></div><h1 className="mt-3 text-3xl font-black tracking-tight text-[#0b2940]">{item.name}</h1><p className="mt-2 flex items-center gap-2 text-slate-600"><MapPin size={17}/>{item.location}</p></div><Link to={`/manage/events/${item.event_id}/edit`} className="btn-primary"><Edit3 size={18}/>Edit Event</Link></div><div className="mt-8 grid gap-5 lg:grid-cols-3"><section className="card p-6 lg:col-span-2"><h2 className="font-bold text-slate-900">Timeline</h2><dl className="mt-5 grid gap-5 sm:grid-cols-2"><Info label="Starts" value={date(item.start_at)} icon={<CalendarDays size={18}/>} /><Info label="Physical Event ends" value={date(item.end_at)} icon={<CalendarDays size={18}/>} /><Info label="Contributions lock" value={date(item.lock_at)} icon={<Clock3 size={18}/>} /><Info label="Public visibility ends" value={date(item.visible_until)} icon={<Clock3 size={18}/>} /></dl><p className="mt-5 text-xs text-slate-500">Timezone: {item.timezone}</p></section><section className="card p-6"><h2 className="font-bold text-slate-900">Public route</h2><p className="mt-3 break-all rounded-xl bg-slate-50 p-3 text-sm text-slate-600">/e/{item.slug}</p><a href={`/e/${item.slug}`} className="btn-secondary mt-4 w-full">Open public page<ExternalLink size={17}/></a><div className="mt-6 border-t border-slate-100 pt-5"><p className="text-sm font-semibold text-slate-700">Exhibitors</p><p className="mt-1 text-sm text-slate-500">Exhibitor management is the next implementation phase.</p></div></section></div></>
}

function Info({label,value,icon}:{label:string;value:string;icon:React.ReactNode}){return <div className="flex gap-3"><span className="mt-0.5 text-[#ef5b32]">{icon}</span><div><dt className="text-xs font-bold uppercase tracking-wider text-slate-400">{label}</dt><dd className="mt-1 font-semibold text-slate-800">{value}</dd></div></div>}

