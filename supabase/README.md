# ExpoPulse Supabase setup

1. Create the protected Admin in **Authentication → Users** using a real email address.
2. Open the Supabase SQL editor and apply `migrations/202608240001_initial_schema.sql`.
3. In the trusted SQL editor, bootstrap that Auth user once:

```sql
select public.bootstrap_protected_admin('admin@example.com', 'Admin');
```

4. Create and verify the intended Editor Auth account with `display_name` set to `Editor01`.
5. Sign in as Admin and promote `Editor01` on **Management → Users & roles**.

Do not place the service-role key in the Vite application or Git repository.

