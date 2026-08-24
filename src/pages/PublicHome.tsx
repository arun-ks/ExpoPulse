import { ArrowRight, CalendarDays, MapPin } from 'lucide-react'
import { Link } from 'react-router-dom'
import { Brand } from '../components/Brand'
import { useAuth } from '../providers/AuthProvider'

export function PublicHome() {
  const { profile } = useAuth()
  return <main className="min-h-screen bg-[#f4f7f9]">
    <header className="border-b border-slate-200 bg-white"><div className="mx-auto flex max-w-7xl items-center justify-between px-5 py-4"><Brand /><Link className="btn-secondary" to={profile && ['admin','editor'].includes(profile.role) ? '/manage' : '/login'}>{profile ? 'Management' : 'Sign in'}<ArrowRight size={17} /></Link></div></header>
    <section className="mx-auto max-w-7xl px-5 py-16 md:py-24"><span className="text-sm font-black uppercase tracking-[.2em] text-[#ef5b32]">Discover what matters</span><h1 className="mt-4 max-w-3xl text-5xl font-black tracking-tight text-[#0b2940] md:text-7xl">Find the people and ideas shaping your event.</h1><p className="mt-6 max-w-2xl text-lg leading-8 text-slate-600">Browse exhibitors, locate booths and share thoughtful feedback—all from your phone.</p>
      <div className="card mt-14 p-8 text-center"><div className="mx-auto grid size-14 place-items-center rounded-2xl bg-orange-50 text-[#ef5b32]"><CalendarDays /></div><h2 className="mt-4 text-xl font-bold text-slate-900">No public events yet</h2><p className="mt-2 text-slate-500">Visible events will appear here once the Admin publishes them.</p><div className="mt-5 inline-flex items-center gap-2 text-sm text-slate-500"><MapPin size={16} />Ready for your next expo</div></div>
    </section>
  </main>
}

