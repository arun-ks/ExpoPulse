import { Activity } from 'lucide-react'
import { Link } from 'react-router-dom'

export function Brand({ compact = false }: { compact?: boolean }) {
  return (
    <Link to="/" className="inline-flex items-center gap-2.5 text-slate-900" aria-label="ExpoPulse home">
      <span className="grid size-10 place-items-center rounded-xl bg-[#ef5b32] text-white shadow-sm"><Activity size={22} /></span>
      {!compact && <span className="text-xl font-black tracking-tight">Expo<span className="text-[#ef5b32]">Pulse</span></span>}
    </Link>
  )
}

