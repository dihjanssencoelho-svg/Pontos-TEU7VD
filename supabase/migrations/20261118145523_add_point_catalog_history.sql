-- Record future point changes and preserve already approved revisions.
-- This migration does not modify public.points or the protected backup.
create table public.point_catalog_history (
  history_id uuid primary key default gen_random_uuid(),
  source_review_id uuid unique references public.point_text_reviews(review_id),
  point_id text not null,
  operation text not null check (operation in ('insert', 'update', 'delete')),
  before_content jsonb,
  after_content jsonb,
  changed_by uuid references auth.users(id),
  changed_at timestamptz not null default now()
);

create index point_catalog_history_changed_at_idx
  on public.point_catalog_history (changed_at desc);
create index point_catalog_history_point_idx
  on public.point_catalog_history (point_id, changed_at desc);

alter table public.point_catalog_history enable row level security;
revoke all on public.point_catalog_history from anon, authenticated;
grant select on public.point_catalog_history to authenticated;
create policy "Temple editors can read point catalog history"
  on public.point_catalog_history for select to authenticated
  using ((select auth.jwt() -> 'app_metadata' ->> 'role') in ('admin', 'temple_member'));

-- Approved reviews already contain the exact accepted snapshot; copy them into the history view once.
insert into public.point_catalog_history (
  source_review_id, point_id, operation, before_content, after_content, changed_by, changed_at
)
select
  review_id,
  point_id,
  operation,
  original_content,
  coalesce(approved_content, proposed_content),
  decided_by,
  coalesce(decided_at, submitted_at)
from public.point_text_reviews
where status = 'approved'
on conflict (source_review_id) do nothing;

-- Existing soft-deleted points can be shown in history from their last recorded update timestamp.
insert into public.point_catalog_history (
  point_id, operation, before_content, after_content, changed_at
)
select
  id,
  'delete',
  jsonb_set(to_jsonb(point) - 'updated_at', '{is_deleted}', 'false'::jsonb),
  to_jsonb(point) - 'updated_at',
  updated_at
from public.points as point
where is_deleted = true;

create or replace function public.capture_point_catalog_history()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_operation text;
  v_point_id text;
  v_before jsonb;
  v_after jsonb;
begin
  if tg_op = 'INSERT' then
    v_operation := 'insert';
    v_point_id := new.id;
    v_before := null;
    v_after := to_jsonb(new) - 'updated_at';
  elsif tg_op = 'DELETE' then
    v_operation := 'delete';
    v_point_id := old.id;
    v_before := to_jsonb(old) - 'updated_at';
    v_after := null;
  else
    v_point_id := new.id;
    v_before := to_jsonb(old) - 'updated_at';
    v_after := to_jsonb(new) - 'updated_at';
    if v_before is not distinct from v_after then
      return new;
    end if;
    v_operation := case when new.is_deleted and not old.is_deleted then 'delete' else 'update' end;
  end if;

  insert into public.point_catalog_history (
    point_id, operation, before_content, after_content, changed_by, changed_at
  ) values (
    v_point_id, v_operation, v_before, v_after, auth.uid(), now()
  );

  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

revoke all on function public.capture_point_catalog_history() from public, anon, authenticated;
drop trigger if exists points_catalog_history on public.points;
create trigger points_catalog_history
  after insert or update or delete on public.points
  for each row execute function public.capture_point_catalog_history();

notify pgrst, 'reload schema';
