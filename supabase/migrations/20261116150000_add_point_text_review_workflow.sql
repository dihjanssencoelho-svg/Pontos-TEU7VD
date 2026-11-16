-- Creates a private review queue. This migration does not backfill or update points.
create table if not exists public.point_text_reviews (
  review_id uuid primary key default gen_random_uuid(),
  point_id text not null,
  operation text not null check (operation in ('insert', 'update')),
  original_content jsonb,
  proposed_content jsonb not null,
  suggestions jsonb not null default '[]'::jsonb,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  submitted_by uuid not null references auth.users(id),
  submitted_at timestamptz not null default now(),
  decided_by uuid references auth.users(id),
  decided_at timestamptz,
  decision_note text,
  constraint point_text_reviews_decision_consistency check (
    (status = 'pending' and decided_by is null and decided_at is null)
    or (status <> 'pending' and decided_by is not null and decided_at is not null)
  )
);

create index if not exists point_text_reviews_pending_idx
  on public.point_text_reviews (submitted_at desc) where status = 'pending';
create unique index if not exists point_text_reviews_one_pending_per_point_idx
  on public.point_text_reviews (point_id) where status = 'pending';
create index if not exists point_text_reviews_point_idx
  on public.point_text_reviews (point_id, submitted_at desc);

alter table public.point_text_reviews enable row level security;
revoke all on public.point_text_reviews from anon, authenticated;
grant select on public.point_text_reviews to authenticated;
create policy "Temple editors can read text review history"
  on public.point_text_reviews for select to authenticated
  using ((select auth.jwt() -> 'app_metadata' ->> 'role') in ('admin', 'temple_member'));

-- All new records and future edits to title, subtitle, or lyrics must go through review.
-- Remove broad table grants (including TRUNCATE, which is not governed by RLS),
-- then restore only catalog reads for the public client roles.
revoke all on public.points from anon, authenticated;
grant select on public.points to anon, authenticated;

create or replace function public.submit_point_text_review(
  p_point_id text,
  p_proposed_content jsonb,
  p_suggestions jsonb default '[]'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role text := auth.jwt() -> 'app_metadata' ->> 'role';
  v_point public.points%rowtype;
  v_operation text;
  v_original jsonb;
  v_review_id uuid;
begin
  if coalesce(v_role, '') not in ('admin', 'temple_member') or auth.uid() is null then
    raise exception 'not authorized' using errcode = '42501';
  end if;
  if p_point_id is null or length(p_point_id) = 0
     or jsonb_typeof(p_proposed_content) <> 'object'
     or jsonb_typeof(coalesce(p_suggestions, '[]'::jsonb)) <> 'array'
     or nullif(btrim(p_proposed_content ->> 'title'), '') is null
     or nullif(btrim(p_proposed_content ->> 'category'), '') is null
     or nullif(btrim(p_proposed_content ->> 'work_group'), '') is null then
    raise exception 'invalid review content' using errcode = '22023';
  end if;
  select * into v_point from public.points where id = p_point_id for update;
  if found then
    v_operation := 'update';
    v_original := jsonb_build_object(
      'title', v_point.title, 'category', v_point.category, 'work_group', v_point.work_group,
      'subtitle', v_point.subtitle, 'source', v_point.source, 'lyrics', v_point.lyrics,
      'video_url', v_point.video_url, 'audio_url', v_point.audio_url, 'is_deleted', v_point.is_deleted
    );
  else
    v_operation := 'insert';
    v_original := null;
  end if;
  if exists (select 1 from public.point_text_reviews where point_id = p_point_id and status = 'pending') then
    raise exception 'a review is already pending for this point' using errcode = '23505';
  end if;
  insert into public.point_text_reviews (
    point_id, operation, original_content, proposed_content, suggestions, submitted_by
  ) values (
    p_point_id, v_operation, v_original, p_proposed_content,
    coalesce(p_suggestions, '[]'::jsonb), auth.uid()
  ) returning review_id into v_review_id;
  return v_review_id;
end;
$$;

create or replace function public.decide_point_text_review(
  p_review_id uuid,
  p_decision text,
  p_decision_note text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role text := auth.jwt() -> 'app_metadata' ->> 'role';
  v_review public.point_text_reviews%rowtype;
  v_content jsonb;
begin
  if coalesce(v_role, '') not in ('admin', 'temple_member') or auth.uid() is null then
    raise exception 'not authorized' using errcode = '42501';
  end if;
  if p_decision not in ('approved', 'rejected') then
    raise exception 'decision must be approved or rejected' using errcode = '22023';
  end if;
  select * into v_review from public.point_text_reviews where review_id = p_review_id for update;
  if not found or v_review.status <> 'pending' then
    raise exception 'pending review not found' using errcode = 'P0002';
  end if;
  if p_decision = 'approved' then
    v_content := v_review.proposed_content;
    if v_review.operation = 'insert' then
      insert into public.points (
        id, title, category, work_group, subtitle, source, lyrics, video_url, audio_url, is_deleted
      ) values (
        v_review.point_id, v_content ->> 'title', v_content ->> 'category', v_content ->> 'work_group',
        coalesce(v_content ->> 'subtitle', ''), coalesce(v_content ->> 'source', ''),
        coalesce(v_content ->> 'lyrics', ''), coalesce(v_content ->> 'video_url', ''),
        coalesce(v_content ->> 'audio_url', ''), false
      );
    else
      update public.points set
        title = v_content ->> 'title', category = v_content ->> 'category',
        work_group = v_content ->> 'work_group', subtitle = coalesce(v_content ->> 'subtitle', ''),
        source = coalesce(v_content ->> 'source', ''), lyrics = coalesce(v_content ->> 'lyrics', ''),
        video_url = coalesce(v_content ->> 'video_url', ''), audio_url = coalesce(v_content ->> 'audio_url', ''),
        is_deleted = false
      where id = v_review.point_id;
      if not found then raise exception 'point no longer exists' using errcode = 'P0002'; end if;
    end if;
  end if;
  update public.point_text_reviews set
    status = p_decision, decided_by = auth.uid(), decided_at = now(),
    decision_note = nullif(btrim(p_decision_note), '')
  where review_id = p_review_id;
end;
$$;

create or replace function public.soft_delete_point(p_point_id text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role text := auth.jwt() -> 'app_metadata' ->> 'role';
begin
  if coalesce(v_role, '') not in ('admin', 'temple_member') or auth.uid() is null then
    raise exception 'not authorized' using errcode = '42501';
  end if;
  if exists (select 1 from public.point_text_reviews where point_id = p_point_id and status = 'pending') then
    raise exception 'resolve the pending text review before deleting this point' using errcode = '23505';
  end if;
  update public.points set is_deleted = true where id = p_point_id;
  if not found then raise exception 'point not found' using errcode = 'P0002'; end if;
end;
$$;

-- Metadata-only edits do not change reviewed text and remain immediate.
create or replace function public.update_point_metadata(
  p_point_id text,
  p_category text,
  p_work_group text,
  p_source text default '',
  p_video_url text default '',
  p_audio_url text default ''
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role text := auth.jwt() -> 'app_metadata' ->> 'role';
begin
  if coalesce(v_role, '') not in ('admin', 'temple_member') or auth.uid() is null then
    raise exception 'not authorized' using errcode = '42501';
  end if;
  update public.points set
    category = p_category, work_group = p_work_group,
    source = coalesce(p_source, ''), video_url = coalesce(p_video_url, ''),
    audio_url = coalesce(p_audio_url, '')
  where id = p_point_id;
  if not found then raise exception 'point not found' using errcode = 'P0002'; end if;
end;
$$;

revoke all on function public.submit_point_text_review(text, jsonb, jsonb) from public, anon;
revoke all on function public.decide_point_text_review(uuid, text, text) from public, anon;
revoke all on function public.soft_delete_point(text) from public, anon;
revoke all on function public.update_point_metadata(text, text, text, text, text, text) from public, anon;
grant execute on function public.submit_point_text_review(text, jsonb, jsonb) to authenticated;
grant execute on function public.decide_point_text_review(uuid, text, text) to authenticated;
grant execute on function public.soft_delete_point(text) to authenticated;
grant execute on function public.update_point_metadata(text, text, text, text, text, text) to authenticated;
