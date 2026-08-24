import { Activity, CalendarDays, ChevronRight, FileText, LayoutDashboard, LogOut, Menu, MessageSquareWarning, Shield, Users, X } from 'lucide-react'
import { useState } from 'react'
import { Link, NavLink, Outlet } from 'react-router-dom'
import { useAuth } from '../providers/AuthProvider'
import { Brand } from '../components/Brand'

const baseLinks = [
  { to: '/manage', label: 'Overview', icon: LayoutDashboard, end: true },
  { to: '/manage/events', label: 'Events', icon: CalendarDays },
  { to: '/manage/moderation', label: 'Moderation', icon: MessageSquareWarning },
]
const adminLinks = [
  { to: '/manage/users', label: 'Users & roles', icon: Users },
  { to: '/manage/submissions', label: 'Submissions', icon: FileText },
  { to: '/manage/audit', label: 'Audit log', icon: Shield },
]

export function ManagementLayout() {
  const { profile, signOut } = useAuth()
  const [open, setOpen] = useState(false)
  const links = profile?.role === 'admin' ? [...baseLinks, ...adminLinks] : baseLinks

  const navigation = <>
    <div className="mb-8 flex items-center justify-between"><Brand /><button onClick={() => setOpen(false)} className="md:hidden" aria-label="Close navigation"><X /></button></div>
    <nav className="space-y-1.5" aria-label="Management">
      {links.map(({ to, label, icon: Icon }) => <NavLink key={to} to={to} end={to === '/manage'} onClick={() => setOpen(false)} className={({ isActive }) => `flex items-center gap-3 rounded-xl px-3 py-3 text-sm font-semibold transition ${isActive ? 'bg-[#0b2940] text-white' : 'text-slate-600 hover:bg-slate-100 hover:text-slate-950'}`}><Icon size={19} />{label}</NavLink>)}
    </nav>
    <div className="mt-auto border-t border-slate-200 pt-5">
      <div className="mb-3 px-2"><p className="truncate text-sm font-bold text-slate-900">{profile?.display_name}</p><p className="text-xs uppercase tracking-wider text-slate-500">{profile?.role}</p></div>
      <Link to="/" className="mb-1 flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-semibold text-slate-600 hover:bg-slate-100"><Activity size={18} />Public portal</Link>
      <button onClick={() => void signOut()} className="flex w-full items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-semibold text-slate-600 hover:bg-slate-100"><LogOut size={18} />Sign out</button>
    </div>
  </>

  return <div className="min-h-screen bg-[#f4f7f9]">
    <aside className="fixed inset-y-0 left-0 z-40 hidden w-64 flex-col border-r border-slate-200 bg-white p-5 md:flex">{navigation}</aside>
    {open && <aside className="fixed inset-y-0 left-0 z-50 flex w-[86%] max-w-xs flex-col bg-white p-5 shadow-2xl md:hidden">{navigation}</aside>}
    {open && <button className="fixed inset-0 z-40 bg-slate-950/35 md:hidden" onClick={() => setOpen(false)} aria-label="Close navigation overlay" />}
    <main className="md:ml-64">
      <header className="sticky top-0 z-30 flex h-16 items-center justify-between border-b border-slate-200 bg-white/95 px-4 backdrop-blur md:px-8"><button className="rounded-lg p-2 md:hidden" onClick={() => setOpen(true)} aria-label="Open navigation"><Menu /></button><div className="ml-auto flex items-center gap-2 text-sm text-slate-500"><span className="size-2 rounded-full bg-emerald-500" />Secure workspace<ChevronRight size={15} /></div></header>
      <div className="mx-auto max-w-7xl p-4 md:p-8"><Outlet /></div>
    </main>
  </div>
}
