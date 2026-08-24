import { CalendarDays, MessageSquareWarning, TrendingUp, Users } from 'lucide-react'
import { Link } from 'react-router-dom'
import { useAuth } from '../providers/AuthProvider'

const cards = [
  { label: 'Events', value: '0', detail: 'No events configured', icon: CalendarDays, to: '/manage/events', tone: 'bg-blue-50 text-blue-700' },
  { label: 'People', value: '—', detail: 'Manage access and roles', icon: Users, to: '/manage/users', tone: 'bg-orange-50 text-[#d94722]', admin: true },
  { label: 'Reports', value: '0', detail: 'No items need review', icon: MessageSquareWarning, to: '/manage/moderation', tone: 'bg-emerald-50 text-emerald-700' },
]

export function DashboardPage() {
  const { profile } = useAuth()
  return <>
    <div className="flex flex-col justify-between gap-4 sm:flex-row sm:items-end"><div><p className="text-sm font-bold uppercase tracking-[.16em] text-[#ef5b32]">Management overview</p><h1 className="mt-2 text-3xl font-black tracking-tight text-[#0b2940]">Good to see you, {profile?.display_name}.</h1><p className="mt-2 text-slate-600">Here’s the current pulse of your event workspace.</p></div><span className="inline-flex items-center gap-2 self-start rounded-full bg-emerald-50 px-3 py-2 text-xs font-bold text-emerald-700"><span className="size-2 rounded-full bg-emerald-500" />System ready</span></div>
    <div className="mt-8 grid gap-4 md:grid-cols-3">{cards.filter(card => !card.admin || profile?.role === 'admin').map(({ label,value,detail,icon:Icon,to,tone }) => <Link to={to} key={label} className="card group p-6 transition hover:-translate-y-0.5 hover:shadow-md"><div className={`grid size-11 place-items-center rounded-xl ${tone}`}><Icon size={21} /></div><p className="mt-6 text-sm font-semibold text-slate-500">{label}</p><div className="mt-1 flex items-end justify-between"><p className="text-3xl font-black text-[#0b2940]">{value}</p><TrendingUp size={18} className="text-slate-300 transition group-hover:text-[#ef5b32]" /></div><p className="mt-2 text-sm text-slate-500">{detail}</p></Link>)}</div>
    <section className="card mt-8 overflow-hidden"><div className="border-b border-slate-200 px-6 py-5"><h2 className="font-bold text-slate-900">Getting started</h2><p className="mt-1 text-sm text-slate-500">Complete these steps to prepare ExpoPulse.</p></div><ol className="divide-y divide-slate-100">{['Create and publish your first event','Add the event tag catalogue','Import or create exhibitors','Review Editor access'].map((step,index)=><li key={step} className="flex items-center gap-4 px-6 py-4"><span className="grid size-8 shrink-0 place-items-center rounded-full bg-slate-100 text-sm font-black text-slate-600">{index+1}</span><span className="font-medium text-slate-700">{step}</span></li>)}</ol></section>
  </>
}

