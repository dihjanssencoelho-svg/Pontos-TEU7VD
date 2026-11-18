-- Record a required reason when a site administrator rejects a community suggestion.
-- This migration changes only the suggestion workflow; it does not modify public.points.

-- Remove the earlier two-argument overload so it cannot bypass the required reason.
drop function if exists public.decide_point_suggestion(uuid, text);

create or replace function public.decide_point_suggestion(
  p_suggestion_id uuid,
  p_decision text,
  p_decision_note text default null
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
  if p_decision = 'rejected' and nullif(btrim(p_decision_note), '') is null then
    raise exception 'a rejection reason is required' using errcode = '22023';
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
    set status = 'rejected', decided_by = auth.uid(), decided_at = now(),
        decision_note = left(btrim(p_decision_note), 500)
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
  select jsonb_build_object('title', p.title, 'category', p.category, 'work_group', p.work_group)
    into v_duplicate
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
  set status = 'approved', decided_by = auth.uid(), decided_at = now(),
      decision_note = null, point_id = v_point_id
  where id = v_suggestion.id;
  return jsonb_build_object('status', 'approved', 'point_id', v_point_id);
end;
$$;

revoke all on function public.decide_point_suggestion(uuid, text, text) from public, anon;
grant execute on function public.decide_point_suggestion(uuid, text, text) to authenticated;
notify pgrst, 'reload schema';
