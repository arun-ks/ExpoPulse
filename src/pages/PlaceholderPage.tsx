import { Construction } from 'lucide-react'

export function PlaceholderPage({ title }: { title: string }) {
  return <><p className="text-sm font-bold uppercase tracking-[.16em] text-[#ef5b32]">ExpoPulse management</p><h1 className="mt-2 text-3xl font-black tracking-tight text-[#0b2940]">{title}</h1><div className="card mt-7 p-12 text-center"><Construction className="mx-auto text-slate-300" size={38} /><p className="mt-4 font-semibold text-slate-700">This workspace is ready for the next implementation phase.</p></div></>
}

