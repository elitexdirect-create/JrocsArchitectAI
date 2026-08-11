# RUN — build-loop test

This is the first end-to-end test of the ArchitectAI build loop: describe an app → get a
working, deployed full-stack app back. It's intentionally small (a task tracker with
per-user accounts) so any breakage points to the loop itself, not app complexity.

## What's here
- Next.js 14 (App Router)
- Supabase (Postgres + Auth + Row Level Security) — schema in `supabase/schema.sql`
- No external UI libraries — plain CSS-in-JS, to keep the loop dependency-light for v1

## Run locally
1. `npm install`
2. Copy `.env.local.example` to `.env.local` and fill in your Supabase anon key
   (find it in Supabase dashboard → Project Settings → API)
3. `npm run dev`

## Deploy
Push this repo to GitHub, then connect it to Vercel, Netlify, or Railway and set the
same two environment variables from `.env.local.example` in the deploy platform's
dashboard.

## Database
The `todos` table is scoped with Row Level Security so each user can only ever see and
edit their own rows. Auth uses Supabase's built-in email/password.
