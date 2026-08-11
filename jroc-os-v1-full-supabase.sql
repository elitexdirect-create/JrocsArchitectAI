-- =========================================================
-- J-ROC OS FULL V1 SUPABASE SQL
-- Includes base OS, Super Admin God Mode, Private Admin Passkeys, and Credit System
-- Run in order as one combined script or split by migration markers.
-- =========================================================


-- =========================================================
-- BEGIN 0001_jroc_os.sql
-- =========================================================

create extension if not exists "pgcrypto";

create or replace function public.is_org_member(org_id uuid) returns boolean language sql security definer set search_path = public as $$ select exists (select 1 from public.organization_members where organization_id = org_id and user_id = auth.uid()); $$;
create or replace function public.is_org_admin(org_id uuid) returns boolean language sql security definer set search_path = public as $$ select exists (select 1 from public.organization_members where organization_id = org_id and user_id = auth.uid() and role in ('owner','admin')); $$;
create or replace function public.is_org_owner(org_id uuid) returns boolean language sql security definer set search_path = public as $$ select exists (select 1 from public.organization_members where organization_id = org_id and user_id = auth.uid() and role = 'owner'); $$;

create table public.profiles (id uuid primary key references auth.users(id) on delete cascade, email text unique not null, full_name text, avatar_url text, plan text not null default 'free' check (plan in ('free','growth','pro','enterprise')), created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create table public.organizations (id uuid primary key default gen_random_uuid(), owner_id uuid not null references auth.users(id) on delete cascade, name text not null, slug text unique, description text, deleted_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create table public.organization_members (id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade, user_id uuid not null references auth.users(id) on delete cascade, role text not null check (role in ('owner','admin','member','viewer')), created_at timestamptz not null default now(), unique (organization_id,user_id));
create table public.goals (id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade, title text not null, description text, goal_type text not null default 'quarterly' check (goal_type in ('vision','annual','quarterly','monthly','weekly')), status text not null default 'active' check (status in ('active','completed','paused','cancelled')), target_date date, progress numeric not null default 0 check (progress >= 0 and progress <= 100), created_by uuid not null references auth.users(id), deleted_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create table public.projects (id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade, goal_id uuid references public.goals(id) on delete set null, title text not null, description text, status text not null default 'planning' check (status in ('planning','active','blocked','completed','archived')), priority text not null default 'medium' check (priority in ('low','medium','high','critical')), start_date date, due_date date, created_by uuid not null references auth.users(id), deleted_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create table public.tasks (id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade, project_id uuid references public.projects(id) on delete cascade, title text not null, description text, status text not null default 'todo' check (status in ('todo','in_progress','blocked','done','cancelled')), priority text not null default 'medium' check (priority in ('low','medium','high','critical')), assigned_to uuid references auth.users(id) on delete set null, created_by uuid not null references auth.users(id), due_date timestamptz, completed_at timestamptz, deleted_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create table public.knowledge_assets (id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade, title text not null, category text, content text, tags text[] default '{}', asset_type text not null default 'note' check (asset_type in ('note','framework','template','playbook','prompt','file','link')), storage_path text, created_by uuid not null references auth.users(id), deleted_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create table public.sops (id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade, title text not null, department text, content text not null, version text not null default '1.0', status text not null default 'draft' check (status in ('draft','active','archived')), created_by uuid not null references auth.users(id), approved_by uuid references auth.users(id), approved_at timestamptz, deleted_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create table public.ai_agents (id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade, name text not null, role text not null, description text, system_prompt text not null, model text not null default 'gpt-4.1-mini', temperature numeric not null default 0.4, active boolean not null default true, created_by uuid not null references auth.users(id), deleted_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create table public.ai_conversations (id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade, user_id uuid not null references auth.users(id) on delete cascade, agent_id uuid references public.ai_agents(id) on delete set null, title text, created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create table public.ai_messages (id uuid primary key default gen_random_uuid(), conversation_id uuid not null references public.ai_conversations(id) on delete cascade, organization_id uuid not null references public.organizations(id) on delete cascade, role text not null check (role in ('system','user','assistant','tool')), content text not null, tokens_used integer default 0, created_at timestamptz not null default now());
create table public.ai_usage_events (id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade, user_id uuid not null references auth.users(id) on delete cascade, agent_id uuid references public.ai_agents(id) on delete set null, event_type text not null default 'chat_completion', tokens_used integer not null default 0, cost_estimate numeric not null default 0, created_at timestamptz not null default now());
create table public.ai_monthly_limits (id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade, plan text not null check (plan in ('free','growth','pro','enterprise')), monthly_request_limit integer not null, monthly_token_limit integer not null, created_at timestamptz not null default now(), unique (organization_id));
create table public.kpis (id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade, name text not null, description text, target numeric, unit text, frequency text not null default 'monthly' check (frequency in ('daily','weekly','monthly','quarterly','annual')), created_by uuid not null references auth.users(id), deleted_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create table public.kpi_entries (id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade, kpi_id uuid not null references public.kpis(id) on delete cascade, value numeric not null, note text, recorded_by uuid not null references auth.users(id), recorded_at timestamptz not null default now());
create table public.marketplace_products (id uuid primary key default gen_random_uuid(), title text not null, description text, product_type text not null check (product_type in ('prompt_pack','agent','template','sop_pack','dashboard','course','playbook','automation')), price numeric not null default 0, currency text not null default 'usd', active boolean not null default true, preview_image_path text, asset_storage_path text, created_by uuid references auth.users(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create table public.purchases (id uuid primary key default gen_random_uuid(), product_id uuid not null references public.marketplace_products(id) on delete restrict, user_id uuid not null references auth.users(id) on delete cascade, stripe_payment_intent_id text, stripe_checkout_session_id text, amount numeric not null, currency text not null default 'usd', status text not null default 'completed' check (status in ('pending','completed','failed','refunded')), created_at timestamptz not null default now());
create table public.subscriptions (id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade, stripe_customer_id text unique, stripe_subscription_id text unique, plan text not null check (plan in ('free','growth','pro','enterprise')), status text not null check (status in ('active','trialing','past_due','canceled','incomplete','unpaid')), current_period_end timestamptz, cancel_at_period_end boolean not null default false, created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create table public.email_logs (id uuid primary key default gen_random_uuid(), user_id uuid references auth.users(id) on delete set null, organization_id uuid references public.organizations(id) on delete cascade, email_type text not null, recipient text not null, status text not null check (status in ('queued','sent','failed')), provider_message_id text, error_message text, created_at timestamptz not null default now());
create table public.audit_logs (id uuid primary key default gen_random_uuid(), organization_id uuid references public.organizations(id) on delete cascade, user_id uuid references auth.users(id) on delete set null, action text not null, entity_type text not null, entity_id uuid, metadata jsonb not null default '{}'::jsonb, ip_address text, user_agent text, created_at timestamptz not null default now());
create table public.agent_knowledge_sources (id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade, agent_id uuid references public.ai_agents(id) on delete cascade, title text not null, content text, source_type text not null default 'text' check (source_type in ('text','file','url','sop','knowledge_asset')), source_ref_id uuid, storage_path text, created_by uuid not null references auth.users(id), created_at timestamptz not null default now());
create table public.agent_versions (id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade, agent_id uuid not null references public.ai_agents(id) on delete cascade, version text not null, prompt text not null, notes text, created_by uuid not null references auth.users(id), created_at timestamptz not null default now());
create table public.courses (id uuid primary key default gen_random_uuid(), title text not null, description text, level text not null default 'beginner' check (level in ('beginner','intermediate','advanced')), price numeric not null default 0, active boolean not null default true, created_by uuid references auth.users(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create table public.lessons (id uuid primary key default gen_random_uuid(), course_id uuid not null references public.courses(id) on delete cascade, title text not null, content text, video_url text, sort_order integer not null default 0, active boolean not null default true, created_at timestamptz not null default now());
create table public.student_progress (id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade, course_id uuid not null references public.courses(id) on delete cascade, lesson_id uuid references public.lessons(id) on delete cascade, completed boolean not null default false, completed_at timestamptz, created_at timestamptz not null default now(), unique (user_id,course_id,lesson_id));
create table public.certificates (id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade, course_id uuid not null references public.courses(id) on delete cascade, certificate_number text unique not null, issued_at timestamptz not null default now());

alter table public.profiles enable row level security; alter table public.organizations enable row level security; alter table public.organization_members enable row level security; alter table public.goals enable row level security; alter table public.projects enable row level security; alter table public.tasks enable row level security; alter table public.knowledge_assets enable row level security; alter table public.sops enable row level security; alter table public.ai_agents enable row level security; alter table public.ai_conversations enable row level security; alter table public.ai_messages enable row level security; alter table public.ai_usage_events enable row level security; alter table public.ai_monthly_limits enable row level security; alter table public.kpis enable row level security; alter table public.kpi_entries enable row level security; alter table public.marketplace_products enable row level security; alter table public.purchases enable row level security; alter table public.subscriptions enable row level security; alter table public.email_logs enable row level security; alter table public.audit_logs enable row level security; alter table public.agent_knowledge_sources enable row level security; alter table public.agent_versions enable row level security; alter table public.courses enable row level security; alter table public.lessons enable row level security; alter table public.student_progress enable row level security; alter table public.certificates enable row level security;

create policy profiles_own on public.profiles for all using (id = auth.uid()) with check (id = auth.uid());
create policy org_select on public.organizations for select using (public.is_org_member(id)); create policy org_insert on public.organizations for insert with check (owner_id = auth.uid()); create policy org_update on public.organizations for update using (public.is_org_admin(id)) with check (public.is_org_admin(id)); create policy org_delete on public.organizations for delete using (public.is_org_owner(id));
create policy members_select on public.organization_members for select using (public.is_org_member(organization_id)); create policy members_insert on public.organization_members for insert with check (public.is_org_admin(organization_id)); create policy members_update on public.organization_members for update using (public.is_org_owner(organization_id)) with check (public.is_org_owner(organization_id)); create policy members_delete on public.organization_members for delete using (public.is_org_owner(organization_id));

create policy goals_member on public.goals for all using (public.is_org_member(organization_id)) with check (public.is_org_member(organization_id));
create policy projects_member on public.projects for all using (public.is_org_member(organization_id)) with check (public.is_org_member(organization_id));
create policy tasks_member on public.tasks for all using (public.is_org_member(organization_id)) with check (public.is_org_member(organization_id));
create policy knowledge_member on public.knowledge_assets for all using (public.is_org_member(organization_id)) with check (public.is_org_member(organization_id));
create policy sops_member on public.sops for all using (public.is_org_member(organization_id)) with check (public.is_org_member(organization_id));
create policy agents_member_read on public.ai_agents for select using (public.is_org_member(organization_id)); create policy agents_admin_write on public.ai_agents for all using (public.is_org_admin(organization_id)) with check (public.is_org_admin(organization_id));
create policy conversations_member on public.ai_conversations for all using (public.is_org_member(organization_id)) with check (public.is_org_member(organization_id));
create policy messages_member on public.ai_messages for all using (public.is_org_member(organization_id)) with check (public.is_org_member(organization_id));
create policy usage_admin_read on public.ai_usage_events for select using (public.is_org_admin(organization_id)); create policy usage_member_insert on public.ai_usage_events for insert with check (public.is_org_member(organization_id));
create policy limits_member on public.ai_monthly_limits for select using (public.is_org_member(organization_id)); create policy limits_admin on public.ai_monthly_limits for all using (public.is_org_admin(organization_id)) with check (public.is_org_admin(organization_id));
create policy kpis_member on public.kpis for all using (public.is_org_member(organization_id)) with check (public.is_org_member(organization_id)); create policy kpi_entries_member on public.kpi_entries for all using (public.is_org_member(organization_id)) with check (public.is_org_member(organization_id));
create policy marketplace_public on public.marketplace_products for select using (active = true); create policy marketplace_creator on public.marketplace_products for all using (created_by = auth.uid()) with check (created_by = auth.uid());
create policy purchases_own on public.purchases for all using (user_id = auth.uid()) with check (user_id = auth.uid()); create policy subscriptions_own on public.subscriptions for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy email_logs_own_admin on public.email_logs for select using (user_id = auth.uid() or public.is_org_admin(organization_id)); create policy email_logs_insert on public.email_logs for insert with check (auth.uid() is not null);
create policy audit_admin_read on public.audit_logs for select using (public.is_org_admin(organization_id)); create policy audit_member_insert on public.audit_logs for insert with check (organization_id is null or public.is_org_member(organization_id));
create policy agent_sources_member on public.agent_knowledge_sources for all using (public.is_org_member(organization_id)) with check (public.is_org_member(organization_id)); create policy agent_versions_member on public.agent_versions for select using (public.is_org_member(organization_id)); create policy agent_versions_admin on public.agent_versions for all using (public.is_org_admin(organization_id)) with check (public.is_org_admin(organization_id));
create policy courses_public on public.courses for select using (active = true); create policy lessons_public on public.lessons for select using (active = true); create policy progress_own on public.student_progress for all using (user_id = auth.uid()) with check (user_id = auth.uid()); create policy certificates_own on public.certificates for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path = public as $$ begin insert into public.profiles (id,email,full_name) values (new.id,new.email,coalesce(new.raw_user_meta_data->>'full_name','')) on conflict (id) do nothing; return new; end; $$;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();
create or replace function public.add_owner_to_organization() returns trigger language plpgsql security definer set search_path = public as $$ begin insert into public.organization_members (organization_id,user_id,role) values (new.id,new.owner_id,'owner') on conflict do nothing; return new; end; $$;
create trigger on_organization_created after insert on public.organizations for each row execute function public.add_owner_to_organization();

insert into public.marketplace_products (title, description, product_type, price, currency, active) values ('J-ROC AI Commander Starter Kit','Starter pack for AI business growth execution.','template',0,'usd',true),('J-ROC Methodology Playbook','Discover, Design, Deploy, Optimize, Scale.','playbook',27,'usd',true),('AI COO Agent Template','Reusable AI COO agent instructions.','agent',97,'usd',true);


-- =========================================================
-- END 0001_jroc_os.sql
-- =========================================================


-- =========================================================
-- BEGIN 0002_super_admin_god_mode.sql
-- =========================================================


-- =========================================================
-- J-ROC OS SUPER ADMIN / GOD MODE MIGRATION
-- Version: 1.1
-- Purpose: Platform-level super admin access with explicit RLS support
-- =========================================================

-- Super admins are platform operators. This table should only be modified
-- by service-role migrations or trusted backend admin tooling.
create table if not exists public.super_admins (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade unique,
  granted_by uuid references auth.users(id) on delete set null,
  reason text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.super_admins enable row level security;

-- Helper function. Security definer allows RLS policies to check super admin status.
create or replace function public.is_super_admin()
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.super_admins sa
    where sa.user_id = auth.uid()
      and sa.active = true
  );
$$;

-- Super admins can view super-admin records. Do not allow public self-promotion.
create policy if not exists "super_admins_select_super_admins"
on public.super_admins
for select
using (public.is_super_admin());

create policy if not exists "super_admins_insert_super_admins"
on public.super_admins
for insert
with check (public.is_super_admin());

create policy if not exists "super_admins_update_super_admins"
on public.super_admins
for update
using (public.is_super_admin())
with check (public.is_super_admin());

create policy if not exists "super_admins_delete_super_admins"
on public.super_admins
for delete
using (public.is_super_admin());

-- Updated role helpers include super admin override.
create or replace function public.is_org_member(org_id uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select public.is_super_admin()
  or exists (
    select 1
    from public.organization_members om
    where om.organization_id = org_id
      and om.user_id = auth.uid()
  );
$$;

create or replace function public.is_org_admin(org_id uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select public.is_super_admin()
  or exists (
    select 1
    from public.organization_members om
    where om.organization_id = org_id
      and om.user_id = auth.uid()
      and om.role in ('owner', 'admin')
  );
$$;

create or replace function public.is_org_owner(org_id uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select public.is_super_admin()
  or exists (
    select 1
    from public.organization_members om
    where om.organization_id = org_id
      and om.user_id = auth.uid()
      and om.role = 'owner'
  );
$$;

-- Platform admin audit helper table for sensitive operations.
create table if not exists public.super_admin_audit_events (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid references auth.users(id) on delete set null,
  action text not null,
  target_type text not null,
  target_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.super_admin_audit_events enable row level security;

create policy if not exists "super_admin_audit_select_super_admins"
on public.super_admin_audit_events
for select
using (public.is_super_admin());

create policy if not exists "super_admin_audit_insert_super_admins"
on public.super_admin_audit_events
for insert
with check (public.is_super_admin());

-- Super admin convenience read access for platform-wide tables not tied to organizations.
-- Marketplace products already have public read and creator write. Add platform override.
create policy if not exists "marketplace_products_super_admin_all"
on public.marketplace_products
for all
using (public.is_super_admin())
with check (public.is_super_admin());

create policy if not exists "courses_super_admin_all"
on public.courses
for all
using (public.is_super_admin())
with check (public.is_super_admin());

create policy if not exists "lessons_super_admin_all"
on public.lessons
for all
using (public.is_super_admin())
with check (public.is_super_admin());

create policy if not exists "subscriptions_super_admin_select"
on public.subscriptions
for select
using (public.is_super_admin());

create policy if not exists "purchases_super_admin_select"
on public.purchases
for select
using (public.is_super_admin());

create policy if not exists "profiles_super_admin_select"
on public.profiles
for select
using (public.is_super_admin());

create policy if not exists "profiles_super_admin_update"
on public.profiles
for update
using (public.is_super_admin())
with check (public.is_super_admin());

-- Indexes
create index if not exists idx_super_admins_user_id on public.super_admins(user_id);
create index if not exists idx_super_admin_audit_actor on public.super_admin_audit_events(actor_user_id);

-- IMPORTANT FIRST SUPER ADMIN BOOTSTRAP:
-- Run this manually with your real user ID in Supabase SQL editor using the service role context:
-- insert into public.super_admins (user_id, reason)
-- values ('YOUR_AUTH_USER_UUID_HERE', 'Initial J-ROC platform owner');


-- =========================================================
-- END 0002_super_admin_god_mode.sql
-- =========================================================


-- =========================================================
-- BEGIN 0003_private_admin_biometrics_credits.sql
-- =========================================================


-- =========================================================
-- J-ROC OS PRIVATE ADMIN, BIOMETRICS, CREDITS, UNLIMITED ADMIN TOKENS
-- Version: 1.2
-- =========================================================

-- Admin passkeys / biometrics. Actual biometric data never touches the DB.
-- WebAuthn stores public key credential data only.
create table if not exists public.admin_passkeys (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  credential_id text not null unique,
  public_key text not null,
  counter bigint not null default 0,
  device_name text,
  transports text[] default '{}',
  backed_up boolean default false,
  created_at timestamptz not null default now(),
  last_used_at timestamptz
);

alter table public.admin_passkeys enable row level security;

create policy if not exists "admin_passkeys_select_own_or_super"
on public.admin_passkeys for select
using (user_id = auth.uid() or public.is_super_admin());

create policy if not exists "admin_passkeys_insert_super"
on public.admin_passkeys for insert
with check (public.is_super_admin());

create policy if not exists "admin_passkeys_update_super"
on public.admin_passkeys for update
using (public.is_super_admin())
with check (public.is_super_admin());

create policy if not exists "admin_passkeys_delete_super"
on public.admin_passkeys for delete
using (public.is_super_admin());

-- Short-lived admin biometric sessions after passkey verification.
create table if not exists public.admin_private_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  session_token_hash text not null unique,
  expires_at timestamptz not null,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  last_seen_at timestamptz
);

alter table public.admin_private_sessions enable row level security;

create policy if not exists "admin_private_sessions_select_own_or_super"
on public.admin_private_sessions for select
using (user_id = auth.uid() or public.is_super_admin());

create policy if not exists "admin_private_sessions_insert_super"
on public.admin_private_sessions for insert
with check (public.is_super_admin());

create policy if not exists "admin_private_sessions_update_super"
on public.admin_private_sessions for update
using (public.is_super_admin())
with check (public.is_super_admin());

-- Credit plans/tier config.
create table if not exists public.credit_plans (
  id uuid primary key default gen_random_uuid(),
  plan text not null unique check (plan in ('free','growth','pro','enterprise')),
  monthly_ai_credits integer not null,
  monthly_token_limit integer not null,
  created_at timestamptz not null default now()
);

alter table public.credit_plans enable row level security;

create policy if not exists "credit_plans_public_read"
on public.credit_plans for select
using (true);

create policy if not exists "credit_plans_super_admin_all"
on public.credit_plans for all
using (public.is_super_admin())
with check (public.is_super_admin());

insert into public.credit_plans (plan, monthly_ai_credits, monthly_token_limit)
values
  ('free', 50, 100000),
  ('growth', 1000, 2500000),
  ('pro', 5000, 12500000),
  ('enterprise', 999999999, 999999999)
on conflict (plan) do update set
  monthly_ai_credits = excluded.monthly_ai_credits,
  monthly_token_limit = excluded.monthly_token_limit;

-- Per-user credit balance. Free tier credits can be granted here.
create table if not exists public.user_credit_balances (
  user_id uuid primary key references auth.users(id) on delete cascade,
  plan text not null default 'free' check (plan in ('free','growth','pro','enterprise')),
  ai_credits_remaining integer not null default 50,
  token_limit_remaining integer not null default 100000,
  period_start timestamptz not null default now(),
  period_end timestamptz not null default (now() + interval '30 days'),
  updated_at timestamptz not null default now()
);

alter table public.user_credit_balances enable row level security;

create policy if not exists "credit_balance_select_own_or_super"
on public.user_credit_balances for select
using (user_id = auth.uid() or public.is_super_admin());

create policy if not exists "credit_balance_update_super"
on public.user_credit_balances for update
using (public.is_super_admin())
with check (public.is_super_admin());

create policy if not exists "credit_balance_insert_super"
on public.user_credit_balances for insert
with check (public.is_super_admin());

-- Ledger tracks all grants and AI credit usage.
create table if not exists public.credit_ledger (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  organization_id uuid references public.organizations(id) on delete cascade,
  event_type text not null check (event_type in ('grant','usage','refund','adjustment','monthly_reset')),
  credits_delta integer not null,
  tokens_delta integer not null default 0,
  source text not null default 'system',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.credit_ledger enable row level security;

create policy if not exists "credit_ledger_select_own_or_super"
on public.credit_ledger for select
using (user_id = auth.uid() or public.is_super_admin());

create policy if not exists "credit_ledger_insert_super_or_self_usage"
on public.credit_ledger for insert
with check (public.is_super_admin() or user_id = auth.uid());

-- Create default free credits when profile is created.
create or replace function public.ensure_default_credit_balance()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.user_credit_balances (user_id, plan, ai_credits_remaining, token_limit_remaining)
  values (new.id, coalesce(new.plan, 'free'), 50, 100000)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_profile_created_credit_balance on public.profiles;
create trigger on_profile_created_credit_balance
after insert on public.profiles
for each row execute function public.ensure_default_credit_balance();

-- Grant credits manually, super admin only by RLS if called from client.
create or replace function public.grant_ai_credits(target_user_id uuid, credits integer, tokens integer, note text default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_super_admin() then
    raise exception 'Only super admins can grant credits';
  end if;

  insert into public.user_credit_balances (user_id, ai_credits_remaining, token_limit_remaining)
  values (target_user_id, credits, tokens)
  on conflict (user_id) do update set
    ai_credits_remaining = public.user_credit_balances.ai_credits_remaining + credits,
    token_limit_remaining = public.user_credit_balances.token_limit_remaining + tokens,
    updated_at = now();

  insert into public.credit_ledger (user_id, event_type, credits_delta, tokens_delta, source, metadata)
  values (target_user_id, 'grant', credits, tokens, 'super_admin', jsonb_build_object('note', note));
end;
$$;

-- Usage function. Super admins consume nothing and are unlimited.
create or replace function public.consume_ai_credit(target_user_id uuid, org_id uuid, tokens_used integer default 0)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  is_admin boolean;
  balance record;
begin
  select exists(select 1 from public.super_admins where user_id = target_user_id and active = true) into is_admin;

  if is_admin then
    insert into public.credit_ledger (user_id, organization_id, event_type, credits_delta, tokens_delta, source, metadata)
    values (target_user_id, org_id, 'usage', 0, 0, 'super_admin_unlimited', jsonb_build_object('tokens_observed', tokens_used));
    return true;
  end if;

  select * into balance from public.user_credit_balances where user_id = target_user_id for update;

  if balance is null then
    insert into public.user_credit_balances (user_id, plan, ai_credits_remaining, token_limit_remaining)
    values (target_user_id, 'free', 50, 100000);
    select * into balance from public.user_credit_balances where user_id = target_user_id for update;
  end if;

  if balance.ai_credits_remaining <= 0 then
    return false;
  end if;

  update public.user_credit_balances
  set ai_credits_remaining = ai_credits_remaining - 1,
      token_limit_remaining = greatest(0, token_limit_remaining - greatest(tokens_used,0)),
      updated_at = now()
  where user_id = target_user_id;

  insert into public.credit_ledger (user_id, organization_id, event_type, credits_delta, tokens_delta, source, metadata)
  values (target_user_id, org_id, 'usage', -1, -greatest(tokens_used,0), 'ai_chat', '{}'::jsonb);

  return true;
end;
$$;

-- Keep ai_monthly_limits compatible with old endpoint behavior.
-- Super admin unlimited is enforced in the Edge Function and consume function.

create index if not exists idx_admin_passkeys_user on public.admin_passkeys(user_id);
create index if not exists idx_admin_private_sessions_user on public.admin_private_sessions(user_id);
create index if not exists idx_credit_ledger_user on public.credit_ledger(user_id);


-- =========================================================
-- END 0003_private_admin_biometrics_credits.sql
-- =========================================================
