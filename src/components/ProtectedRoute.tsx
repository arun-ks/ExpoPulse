import { Navigate, Outlet, useLocation } from 'react-router-dom'
import { useAuth } from '../providers/AuthProvider'
import { LoadingScreen } from './LoadingScreen'

export function ManagementRoute() {
  const { session, profile, loading } = useAuth()
  const location = useLocation()
  if (loading) return <LoadingScreen />
  if (!session) return <Navigate to={`/login?returnTo=${encodeURIComponent(location.pathname)}`} replace />
  if (!profile || !['admin', 'editor'].includes(profile.role)) return <Navigate to="/unauthorized" replace />
  return <Outlet />
}

export function AdminRoute() {
  const { profile, loading } = useAuth()
  if (loading) return <LoadingScreen />
  if (profile?.role !== 'admin') return <Navigate to="/manage" replace />
  return <Outlet />
}

