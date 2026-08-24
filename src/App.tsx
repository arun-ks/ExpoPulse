import { Route, Routes } from 'react-router-dom'
import { AdminRoute, ContributorRoute, ManagementRoute } from './components/ProtectedRoute'
import { ManagementLayout } from './layouts/ManagementLayout'
import { DashboardPage } from './pages/DashboardPage'
import { EventsPage } from './pages/EventsPage'
import { EventDetailPage } from './pages/EventDetailPage'
import { EventFormPage } from './pages/EventFormPage'
import { ExhibitorsPage } from './pages/ExhibitorsPage'
import { ExhibitorFormPage } from './pages/ExhibitorFormPage'
import { ImportPage } from './pages/ImportPage'
import { TagsPage } from './pages/TagsPage'
import { LoginPage } from './pages/LoginPage'
import { PublicHome } from './pages/PublicHome'
import { EventSearchPage } from './pages/EventSearchPage'
import { PublicExhibitorPage } from './pages/PublicExhibitorPage'
import { StatusPage } from './pages/StatusPage'
import { UsersPage } from './pages/UsersPage'
import { ContributorLoginPage } from './pages/ContributorLoginPage'
import { MyFeedbackPage } from './pages/MyFeedbackPage'
import { AdvertisingEnquiryPage } from './pages/AdvertisingEnquiryPage'
import { ContributorProfilePage } from './pages/ContributorProfilePage'
import { ModerationPage } from './pages/ModerationPage'
import { SubmissionsPage } from './pages/SubmissionsPage'
import { AuditLogPage } from './pages/AuditLogPage'

export default function App() {
  return <Routes>
    <Route path="/" element={<PublicHome />} />
    <Route path="/e/:slug" element={<EventSearchPage />} />
    <Route path="/e/:slug/exhibitors/:publicId" element={<PublicExhibitorPage />} />
    <Route path="/login" element={<LoginPage />} />
    <Route path="/contributor/login" element={<ContributorLoginPage />} />
    <Route element={<ContributorRoute />}><Route path="/my-feedback" element={<MyFeedbackPage/>}/><Route path="/advertising" element={<AdvertisingEnquiryPage/>}/><Route path="/profile" element={<ContributorProfilePage/>}/></Route>
    <Route path="/unauthorized" element={<StatusPage />} />
    <Route element={<ManagementRoute />}><Route path="/manage" element={<ManagementLayout />}>
      <Route index element={<DashboardPage />} />
      <Route path="events" element={<EventsPage />} />
      <Route path="events/:eventId" element={<EventDetailPage />} />
      <Route path="events/:eventId/edit" element={<EventFormPage mode="edit" />} />
      <Route path="events/:eventId/exhibitors" element={<ExhibitorsPage />} />
      <Route path="events/:eventId/exhibitors/new" element={<ExhibitorFormPage />} />
      <Route path="events/:eventId/exhibitors/:exhibitorId" element={<ExhibitorFormPage />} />
      <Route path="events/:eventId/tags" element={<TagsPage />} />
      <Route path="moderation" element={<ModerationPage />} />
      <Route element={<AdminRoute />}>
        <Route path="users" element={<UsersPage />} />
        <Route path="events/new" element={<EventFormPage mode="create" />} />
        <Route path="events/:eventId/import" element={<ImportPage />} />
        <Route path="submissions" element={<SubmissionsPage />} />
        <Route path="audit" element={<AuditLogPage />} />
      </Route>
    </Route></Route>
    <Route path="*" element={<StatusPage title="Page not found" message="The page you requested does not exist or is no longer available." />} />
  </Routes>
}
