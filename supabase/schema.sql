create table if not exists public.points (
  id text primary key,
  title text not null,
  category text not null,
  work_group text not null check (work_group in ('Orixás', 'Linhas de trabalho')),
  subtitle text not null default '',
  source text not null default '',
  lyrics text not null default '',
  video_url text not null default '',
  audio_url text not null default '',
  is_deleted boolean not null default false,
  updated_at timestamptz not null default now()
);

alter table public.points add column if not exists video_url text not null default '';
alter table public.points add column if not exists audio_url text not null default '';
alter table public.points add column if not exists is_deleted boolean not null default false;

alter table public.points enable row level security;

grant select on public.points to anon, authenticated;
grant insert, update on public.points to authenticated;

drop policy if exists "Anyone can read points" on public.points;
create policy "Anyone can read points"
  on public.points for select
  to anon, authenticated
  using (true);

drop policy if exists "Admins and temple members can add points" on public.points;
drop policy if exists "Admins can add points" on public.points;
create policy "Admins and temple members can add points"
  on public.points for insert
  to authenticated
  with check ((auth.jwt() -> 'app_metadata' ->> 'role') in ('admin', 'temple_member'));

drop policy if exists "Admins and temple members can edit points" on public.points;
drop policy if exists "Admins can edit points" on public.points;
create policy "Admins and temple members can edit points"
  on public.points for update
  to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'role') in ('admin', 'temple_member'))
  with check ((auth.jwt() -> 'app_metadata' ->> 'role') in ('admin', 'temple_member'));

create or replace function public.set_points_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists points_updated_at on public.points;
create trigger points_updated_at
  before update on public.points
  for each row execute function public.set_points_updated_at();
