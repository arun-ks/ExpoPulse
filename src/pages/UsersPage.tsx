import { CheckCircle2, LockKeyhole, Search, Shield, UserCog } from 'lucide-react'
import { useEffect, useMemo, useState } from 'react'
import { supabase } from '../lib/supabase'
import type { AppRole, Profile } from '../types'

export function UsersPage() {
  const [profiles, setProfiles] = useState<Profile[]>([])
  const [loading, setLoading] = useState(true)
  const [query, setQuery] = useState('')
  const [message, setMessage] = useState('')

  const load = async () => {
    setLoading(true)
    const { data, error } = await supabase.rpc('admin_list_profiles')
    if (error) setMessage(error.message)
    else setProfiles((data ?? []) as Profile[])
    setLoading(false)
  }
  useEffect(() => { void load() }, [])

  const changeRole = async (profileId: string, role: AppRole) => {
    setMessage('')
    const { error } = await supabase.rpc('admin_set_user_role', { target_profile_id: profileId, new_role: role })
    setMessage(error ? error.message : 'Role updated successfully.')
    if (!error) await load()
  }

  const filtered = useMemo(() => profiles.filter(profile => profile.display_name.toLowerCase().includes(query.toLowerCase())), [profiles, query])

  return <>
    <div><p className="text-sm font-bold uppercase tracking-[.16em] text-[#ef5b32]">Access control</p><h1 className="mt-2 text-3xl font-black tracking-tight text-[#0b2940]">Users & roles</h1><p className="mt-2 text-slate-600">Promote Contributors to Editor or return Editors to Contributor access.</p></div>
    <div className="card mt-7 overflow-hidden">
      <div className="flex flex-col gap-4 border-b border-slate-200 p-5 sm:flex-row sm:items-center sm:justify-between"><label className="relative block max-w-sm flex-1"><Search className="absolute left-3 top-3 text-slate-400" size={19} /><input className="field mt-0 pl-10" placeholder="Search by display name" value={query} onChange={e => setQuery(e.target.value)} /></label><span className="text-sm font-semibold text-slate-500">{filtered.length} accounts</span></div>
      {message && <p className="border-b border-slate-200 bg-blue-50 px-5 py-3 text-sm font-medium text-blue-800" role="status">{message}</p>}
      <div className="divide-y divide-slate-100">
        {loading ? <p className="p-8 text-center text-slate-500">Loading accounts…</p> : filtered.length === 0 ? <div className="p-10 text-center"><UserCog className="mx-auto text-slate-300" size={32} /><p className="mt-3 font-semibold text-slate-700">No profiles found</p><p className="mt-1 text-sm text-slate-500">Verified users appear after their first sign-in.</p></div> : filtered.map(profile => <div key={profile.profile_id} className="flex flex-col gap-4 p-5 sm:flex-row sm:items-center sm:justify-between"><div className="flex items-center gap-4"><div className={`grid size-11 place-items-center rounded-xl text-sm font-black ${profile.is_protected_admin ? 'bg-[#0b2940] text-white' : 'bg-orange-50 text-[#d94722]'}`}>{profile.display_name.slice(0,2).toUpperCase()}</div><div><div className="flex items-center gap-2"><p className="font-bold text-slate-900">{profile.display_name}</p>{profile.is_protected_admin && <span title="Protected Admin"><LockKeyhole size={15} className="text-[#ef5b32]" /></span>}</div><p className="mt-0.5 text-xs font-semibold uppercase tracking-wider text-slate-500">{profile.role} · {profile.status}</p></div></div><div className="flex items-center gap-2">{profile.is_protected_admin ? <span className="inline-flex items-center gap-2 rounded-lg bg-slate-100 px-3 py-2 text-sm font-semibold text-slate-600"><Shield size={16} />Protected</span> : <select aria-label={`Role for ${profile.display_name}`} className="field mt-0 min-h-10 py-2" value={profile.role} onChange={e => void changeRole(profile.profile_id, e.target.value as AppRole)}><option value="contributor">Contributor</option><option value="editor">Editor</option></select>}</div></div>)}
      </div>
    </div>
    <div className="mt-5 flex items-start gap-3 rounded-2xl border border-emerald-200 bg-emerald-50 p-4 text-sm text-emerald-900"><CheckCircle2 className="mt-0.5 shrink-0" size={18} /><p><strong>Protected by database policy.</strong> Role changes are validated and audited server-side. The protected Admin cannot be modified.</p></div>
  </>
}

