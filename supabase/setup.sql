-- Ten Things Journal: tables and security.
-- Paste into Supabase → SQL Editor → New query → Run. Safe to run more than once.

-- One row per person: start date, daily goal, app settings.
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  start_date date,
  daily_goal int not null default 10 check (daily_goal between 1 and 50),
  settings jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Every gratitude entry. Numbers are unique per person and never reused.
create table if not exists public.entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  number int not null,
  text text not null check (char_length(text) between 1 and 2000),
  local_date date,                       -- null for undated imports
  source text not null default 'app' check (source in ('app', 'import')),
  created_at timestamptz not null default now(),
  edited_at timestamptz,
  deleted_at timestamptz,                -- soft delete keeps the number reserved
  unique (user_id, number)
);
create index if not exists entries_user_date on public.entries (user_id, local_date);

-- Privacy: each person can only ever see and change their own rows.
alter table public.profiles enable row level security;
alter table public.entries enable row level security;

drop policy if exists "own profile" on public.profiles;
create policy "own profile" on public.profiles
  for all to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

drop policy if exists "own entries" on public.entries;
create policy "own entries" on public.entries
  for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

-- The server gives each new entry the next number, so two phones can't both make #7,200.
create or replace function public.assign_entry_number() returns trigger
language plpgsql set search_path = public as $$
begin
  if new.number is null then
    perform pg_advisory_xact_lock(hashtext(new.user_id::text));
    select coalesce(max(number), 0) + 1 into new.number from public.entries where user_id = new.user_id;
  end if;
  return new;
end $$;

drop trigger if exists entries_number on public.entries;
create trigger entries_number before insert on public.entries
  for each row execute function public.assign_entry_number();

-- New sign-ups get a profile row automatically.
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id) values (new.id) on conflict do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();
