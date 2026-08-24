# ExpoPulse

ExpoPulse is a mobile-first event and exhibitor discovery portal with a protected management console for Admin and Editor roles.

## Current implementation

- Responsive public landing page
- Supabase email/password authentication
- Protected Admin/Editor route shell
- Admin dashboard
- Admin user and role management
- Editor promotion/demotion through audited database functions
- Event management foundation
- Greenfield PostgreSQL schema with RLS enabled
- Protected single-Admin bootstrap function

## Local setup

1. Install dependencies:

   ```sh
   npm install
   ```

2. Copy `.env.example` to `.env.local` and set:

   ```text
   VITE_SUPABASE_URL
   VITE_SUPABASE_ANON_KEY
   ```

3. Apply the Supabase migration described in [`supabase/README.md`](supabase/README.md).

4. Start the app:

   ```sh
   npm run dev
   ```

## Verification

```sh
npm run lint
npm test
npm run build
```

## Deployment

The frontend is configured for Vercel SPA routing through `vercel.json`. Configure the two browser-safe Supabase environment variables in the Vercel project. Never add the Supabase service-role key to Vite configuration.

## Assets

Event and Exhibitor images are deployed from:

```text
public/assets/events/
public/assets/exhibitors/
```

Database asset paths must begin with the corresponding `/assets/` prefix.

