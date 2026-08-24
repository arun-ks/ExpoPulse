import { ArrowLeft, CalendarCheck, Clock3, Globe2, MapPin, Save } from 'lucide-react'
import { useEffect, useMemo, useState, type FormEvent } from 'react'
import { Link, Navigate, useNavigate, useParams } from 'react-router-dom'
import { eventFormDefaults, eventSlug, isoToEventLocal } from '../lib/events'
import { supabase } from '../lib/supabase'
import { useAuth } from '../providers/AuthProvider'
import type { EventSummary } from '../types'

const timezones = ['Asia/Singapore','Asia/Kuala_Lumpur','Asia/Bangkok','Asia/Jakarta','Asia/Manila','Asia/Tokyo','Asia/Seoul','Asia/Dubai','Europe/London','America/New_York','America/Los_Angeles','Australia/Sydney']

type FormState = { name:string; slug:string; location:string; assetPath:string; timezone:string; start:string; end:string; lock:string; visibleUntil:string; status:'draft'|'active'|'archived' }

export function EventFormPage({ mode }: { mode: 'create' | 'edit' }) {
  const { eventId } = useParams()
  const { profile } = useAuth()
  const navigate = useNavigate()
  const defaults = useMemo(() => eventFormDefaults(), [])
  const [form, setForm] = useState<FormState>({ name:'', slug:'', location:'', assetPath:'', timezone:Intl.DateTimeFormat().resolvedOptions().timeZone || 'Asia/Singapore', start:defaults.start, end:defaults.end, lock:defaults.lock, visibleUntil:defaults.visibleUntil, status:'draft' })
  const [loading, setLoading] = useState(mode === 'edit')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  const [slugTouched, setSlugTouched] = useState(false)
  const [slugLocked, setSlugLocked] = useState(false)

  useEffect(() => {
    if (mode !== 'edit' || !eventId) return
    void supabase.rpc('manage_get_event', { p_event_id: eventId }).then(({ data, error: loadError }) => {
      if (loadError || !data?.[0]) { setError(loadError?.message ?? 'Event not found'); setLoading(false); return }
      const item = data[0] as EventSummary
      setForm({ name:item.name, slug:item.slug, location:item.location, assetPath:item.asset_path ?? '', timezone:item.timezone, start:isoToEventLocal(item.start_at,item.timezone), end:isoToEventLocal(item.end_at,item.timezone), lock:isoToEventLocal(item.lock_at,item.timezone), visibleUntil:isoToEventLocal(item.visible_until,item.timezone), status:item.status })
      setSlugLocked(Boolean(item.slug_locked_at) || (item.status === 'active' && Date.now() >= new Date(item.start_at).getTime() - 7*86_400_000))
      setLoading(false)
    })
  }, [eventId, mode])

  if (mode === 'create' && profile?.role !== 'admin') return <Navigate to="/manage/events" replace />
  const update = (key: keyof FormState, value: string) => setForm(previous => ({ ...previous, [key]: value }))
  const nameChanged = (value: string) => { update('name',value); if (!slugTouched && mode === 'create') update('slug',eventSlug(value)) }

  const submit = async (event: FormEvent) => {
    event.preventDefault(); setBusy(true); setError('')
    if (!(form.start < form.end && form.end <= form.lock && form.lock <= form.visibleUntil)) { setError('Dates must satisfy Start < End ≤ Lock ≤ Visible until.'); setBusy(false); return }
    const common = { p_name:form.name, p_slug:form.slug, p_location:form.location, p_asset_path:form.assetPath, p_timezone:form.timezone, p_start_local:form.start, p_end_local:form.end, p_lock_local:form.lock, p_visible_until_local:form.visibleUntil, p_status:form.status }
    const result = mode === 'create' ? await supabase.rpc('admin_create_event', common) : await supabase.rpc('manage_update_event', { p_event_id:eventId, ...common })
    if (result.error) { setError(result.error.message); setBusy(false); return }
    const saved = result.data?.[0] as EventSummary | undefined
    navigate(saved ? `/manage/events/${saved.event_id}` : '/manage/events', { replace:true })
  }

  if (loading) return <p className="p-10 text-center text-slate-500">Loading Event…</p>
  const editor = profile?.role === 'editor'

  return <>
    <Link to={eventId ? `/manage/events/${eventId}` : '/manage/events'} className="inline-flex items-center gap-2 text-sm font-semibold text-slate-500 hover:text-slate-900"><ArrowLeft size={17} />Back</Link>
    <div className="mt-5"><p className="text-sm font-bold uppercase tracking-[.16em] text-[#ef5b32]">Event configuration</p><h1 className="mt-2 text-3xl font-black tracking-tight text-[#0b2940]">{mode === 'create' ? 'Create an Event' : 'Edit Event'}</h1><p className="mt-2 text-slate-600">Times are entered in the selected Event timezone.</p></div>
    <form onSubmit={submit} className="mt-7 grid gap-6 xl:grid-cols-[1fr_360px]">
      <div className="space-y-6">
        <section className="card p-6"><div className="flex items-center gap-3"><div className="grid size-10 place-items-center rounded-xl bg-orange-50 text-[#ef5b32]"><CalendarCheck size={20}/></div><div><h2 className="font-bold text-slate-900">Event identity</h2><p className="text-sm text-slate-500">The information visitors will recognize.</p></div></div><div className="mt-6 grid gap-5 sm:grid-cols-2">
          <label className="block sm:col-span-2"><span className="label">Event name</span><input className="field" required maxLength={160} value={form.name} onChange={e=>nameChanged(e.target.value)} /></label>
          <label className="block"><span className="label">Public slug</span><input className="field" required pattern="[a-z0-9]+(?:-[a-z0-9]+)*" disabled={slugLocked || editor} value={form.slug} onChange={e=>{setSlugTouched(true);update('slug',eventSlug(e.target.value))}} /><span className="mt-1.5 block text-xs text-slate-500">/e/{form.slug || 'event-name'}</span></label>
          <label className="block"><span className="label">Location</span><div className="relative"><MapPin className="absolute left-3 top-4 text-slate-400" size={17}/><input className="field pl-10" required maxLength={240} value={form.location} onChange={e=>update('location',e.target.value)} /></div></label>
          <label className="block sm:col-span-2"><span className="label">Public asset path <span className="font-normal text-slate-400">(optional)</span></span><input className="field" placeholder="/assets/events/event-logo.webp" value={form.assetPath} onChange={e=>update('assetPath',e.target.value)} /></label>
        </div></section>
        <section className="card p-6"><div className="flex items-center gap-3"><div className="grid size-10 place-items-center rounded-xl bg-blue-50 text-blue-700"><Clock3 size={20}/></div><div><h2 className="font-bold text-slate-900">Schedule</h2><p className="text-sm text-slate-500">Contribution remains open until the lock time.</p></div></div><div className="mt-6 grid gap-5 sm:grid-cols-2">
          <label className="block sm:col-span-2"><span className="label">Timezone</span><div className="relative"><Globe2 className="absolute left-3 top-4 text-slate-400" size={17}/><select className="field pl-10" value={form.timezone} onChange={e=>update('timezone',e.target.value)}>{[...new Set([form.timezone,...timezones])].map(zone=><option key={zone}>{zone}</option>)}</select></div></label>
          <DateField label="Starts" value={form.start} onChange={value=>update('start',value)} /><DateField label="Physical Event ends" value={form.end} onChange={value=>update('end',value)} /><DateField label="Ratings & Comments lock" value={form.lock} onChange={value=>update('lock',value)} /><DateField label="Public visibility ends" value={form.visibleUntil} disabled={editor} onChange={value=>update('visibleUntil',value)} />
        </div></section>
      </div>
      <aside><section className="card sticky top-24 p-6"><h2 className="font-bold text-slate-900">Publication</h2><p className="mt-1 text-sm leading-6 text-slate-500">Draft Events remain private. Active Events become visible seven days before they start.</p><label className="mt-5 block"><span className="label">Status</span><select className="field" disabled={editor} value={form.status} onChange={e=>update('status',e.target.value)}><option value="draft">Draft</option><option value="active">Active</option>{mode==='edit'&&<option value="archived">Archived</option>}</select></label>{error&&<p className="mt-4 rounded-xl bg-red-50 p-3 text-sm font-medium text-red-700" role="alert">{error}</p>}<button className="btn-primary mt-6 w-full" disabled={busy}><Save size={18}/>{busy?'Saving…':mode==='create'?'Create Event':'Save changes'}</button><p className="mt-4 text-xs leading-5 text-slate-500">All changes are validated and audited by the database.</p></section></aside>
    </form>
  </>
}

function DateField({label,value,onChange,disabled=false}:{label:string;value:string;onChange:(value:string)=>void;disabled?:boolean}) {
  return <label className="block"><span className="label">{label}</span><input className="field" type="datetime-local" required disabled={disabled} value={value} onChange={e=>onChange(e.target.value)} /></label>
}

