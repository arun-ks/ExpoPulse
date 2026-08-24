import { ArrowLeft, ShieldAlert } from 'lucide-react'
import { Link } from 'react-router-dom'

export function StatusPage({ title = 'Access unavailable', message = 'You do not have permission to open this page.' }: { title?: string; message?: string }) {
  return <main className="grid min-h-screen place-items-center bg-slate-50 p-6"><div className="card max-w-lg p-9 text-center"><div className="mx-auto grid size-14 place-items-center rounded-2xl bg-orange-50 text-[#ef5b32]"><ShieldAlert /></div><h1 className="mt-5 text-2xl font-black text-[#0b2940]">{title}</h1><p className="mt-3 text-slate-600">{message}</p><Link to="/" className="btn-secondary mt-7"><ArrowLeft size={17} />Return home</Link></div></main>
}

