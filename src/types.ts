export type AppRole = 'contributor' | 'editor' | 'admin'
export type ProfileStatus = 'active' | 'suspended' | 'anonymized'

export interface Profile {
  profile_id: string
  auth_user_id: string | null
  display_name: string
  role: AppRole
  status: ProfileStatus
  is_protected_admin: boolean
  created_at: string
}

export interface EventSummary {
  event_id: string
  name: string
  slug: string
  location: string
  status: 'draft' | 'active' | 'archived'
  start_at: string
  end_at: string
  lock_at: string
  visible_until: string
}

