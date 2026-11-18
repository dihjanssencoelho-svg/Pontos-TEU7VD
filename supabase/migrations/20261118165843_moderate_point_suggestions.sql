-- Community suggestions stay private until a site administrator approves them.
-- This migration adds workflow metadata and does not modify existing catalog rows.
alter table public.point_suggestions
  add column status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  add column decided_by uuid references auth.users(id),
  add column decided_at timestamptz,
  add column decision_note text,
  add column point_id text;

create index point_suggestions_pending_idx
  on public.point_suggestions (submitted_at desc)
  where status = 'pending';

create or replace function public.decide_point_suggestion(
  p_suggestion_id uuid,
  p_decision text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role text := auth.jwt() -> 'app_metadata' ->> 'role';
  v_suggestion public.point_suggestions%rowtype;
  v_title text;
  v_point_id text;
  v_duplicate jsonb;
begin
  if coalesce(v_role, '') <> 'admin' or auth.uid() is null then
    raise exception 'not authorized' using errcode = '42501';
  end if;
  if p_decision not in ('approved', 'rejected') then
    raise exception 'decision must be approved or rejected' using errcode = '22023';
  end if;

  select * into v_suggestion
  from public.point_suggestions
  where id = p_suggestion_id
  for update;
  if not found or v_suggestion.status <> 'pending' then
    raise exception 'pending point suggestion not found' using errcode = 'P0002';
  end if;

  if p_decision = 'rejected' then
    update public.point_suggestions
    set status = 'rejected', decided_by = auth.uid(), decided_at = now()
    where id = v_suggestion.id;
    return jsonb_build_object('status', 'rejected');
  end if;

  if not (
    (v_suggestion.work_group = 'Orixás' and v_suggestion.category = any (array['Oxalá','Ogum','Oxóssi','Xangô','Iansã','Oxum','Iemanjá','Obaluaê','Omolu','Nanã','Obá','Logunan','Oroiná','Oxumaré']))
    or (v_suggestion.work_group = 'Linhas de trabalho' and v_suggestion.category = any (array['Erês / Ibejada','Caboclos','Pretos Velhos','Baianos','Marinheiros','Boiadeiros','Exus','Malandros','Pombagiras','Exu Mirim','Pombogira Mirim','Ciganos']))
    or (v_suggestion.work_group = 'Ritualística' and v_suggestion.category = any (array['Defumação','Abertura']))
  ) then
    raise exception 'invalid point category' using errcode = '22023';
  end if;

  v_title := coalesce(
    nullif(btrim(v_suggestion.name), ''),
    nullif(left((regexp_split_to_array(btrim(v_suggestion.lyrics), E'\\r?\\n'))[1], 120), ''),
    'Ponto indicado'
  );
  select jsonb_build_object(
    'title', p.title,
    'category', p.category,
    'work_group', p.work_group
  ) into v_duplicate
  from public.points as p
  where p.is_deleted = false
    and (
      lower(regexp_replace(btrim(p.title), E'\\s+', ' ', 'g')) = lower(regexp_replace(btrim(v_title), E'\\s+', ' ', 'g'))
      or lower(regexp_replace(btrim(p.lyrics), E'\\s+', ' ', 'g')) = lower(regexp_replace(btrim(v_suggestion.lyrics), E'\\s+', ' ', 'g'))
    )
  limit 1;
  if v_duplicate is not null then
    return jsonb_build_object('status', 'duplicate', 'match', v_duplicate);
  end if;

  v_point_id := 'suggestion:' || v_suggestion.id::text;
  insert into public.points (
    id, title, category, work_group, subtitle, source, lyrics,
    video_url, audio_url, is_deleted
  ) values (
    v_point_id, v_title, v_suggestion.category, v_suggestion.work_group,
    '', 'Indicação da comunidade', v_suggestion.lyrics,
    coalesce(v_suggestion.youtube_url, ''), '', false
  );

  update public.point_suggestions
  set status = 'approved', decided_by = auth.uid(), decided_at = now(), point_id = v_point_id
  where id = v_suggestion.id;
  return jsonb_build_object('status', 'approved', 'point_id', v_point_id);
end;
$$;

revoke all on function public.decide_point_suggestion(uuid, text) from public, anon;
grant execute on function public.decide_point_suggestion(uuid, text) to authenticated;
notify pgrst, 'reload schema';

