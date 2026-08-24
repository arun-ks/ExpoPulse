import { CalendarPlus, CalendarX2 } from 'lucide-react'
import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import { useAuth } from '../providers/AuthProvider'
import type { EventSummary } from '../types'

export function EventsPage() {
  const { profile } = useAuth()
  const [events, setEvents] = useState<EventSummary[]>([])
  const [loading, setLoading] = useState(true)
  useEffect(() => { void supabase.rpc('manage_list_events').then(({ data }) => { setEvents((data ?? []) as EventSummary[]); setLoading(false) }) }, [])
  return <><div className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between"><div><p className="text-sm font-bold uppercase tracking-[.16em] text-[#ef5b32]">Event operations</p><h1 className="mt-2 text-3xl font-black tracking-tight text-[#0b2940]">Events</h1><p className="mt-2 text-slate-600">Configure visibility, contribution windows and exhibitor data.</p></div>{profile?.role === 'admin' && <Link to="/manage/events/new" className="btn-primary"><CalendarPlus size={18} />Create event</Link>}</div><section className="card mt-7 overflow-hidden">{loading ? <p className="p-10 text-center text-slate-500">Loading events…</p> : events.length === 0 ? <div className="p-12 text-center"><CalendarX2 className="mx-auto text-slate-300" size={38} /><h2 className="mt-4 text-xl font-bold text-slate-800">No events yet</h2><p className="mt-2 text-slate-500">Create the first Event to begin adding exhibitors.</p></div> : <div className="divide-y divide-slate-100">{events.map(event => <div key={event.event_id} className="p-5"><p className="font-bold text-slate-900">{event.name}</p><p className="text-sm text-slate-500">{event.location} · {event.status}</p></div>)}</div>}</section></>
}

