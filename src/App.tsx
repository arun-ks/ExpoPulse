import { Route, Routes } from 'react-router-dom'
import { AdminRoute, ManagementRoute } from './components/ProtectedRoute'
import { ManagementLayout } from './layouts/ManagementLayout'
import { DashboardPage } from './pages/DashboardPage'
import { EventsPage } from './pages/EventsPage'
import { EventDetailPage } from './pages/EventDetailPage'
import { EventFormPage } from './pages/EventFormPage'
import { LoginPage } from './pages/LoginPage'
import { PlaceholderPage } from './pages/PlaceholderPage'
import { PublicHome } from './pages/PublicHome'
import { StatusPage } from './pages/StatusPage'
import { UsersPage } from './pages/UsersPage'

export default function App() {
  return <Routes>
    <Route path="/" element={<PublicHome />} />
    <Route path="/login" element={<LoginPage />} />
    <Route path="/unauthorized" element={<StatusPage />} />
    <Route element={<ManagementRoute />}><Route path="/manage" element={<ManagementLayout />}>
      <Route index element={<DashboardPage />} />
      <Route path="events" element={<EventsPage />} />
      <Route path="events/:eventId" element={<EventDetailPage />} />
      <Route path="events/:eventId/edit" element={<EventFormPage mode="edit" />} />
      <Route path="moderation" element={<PlaceholderPage title="Moderation" />} />
      <Route element={<AdminRoute />}>
        <Route path="users" element={<UsersPage />} />
        <Route path="events/new" element={<EventFormPage mode="create" />} />
        <Route path="submissions" element={<PlaceholderPage title="Submissions" />} />
        <Route path="audit" element={<PlaceholderPage title="Audit log" />} />
      </Route>
    </Route></Route>
    <Route path="*" element={<StatusPage title="Page not found" message="The page you requested does not exist or is no longer available." />} />
  </Routes>
}
