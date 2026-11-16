-- Preserve submitted proposals and audit the exact content accepted by a reviewer.
alter table public.point_text_reviews
  add column if not exists approved_content jsonb,
  add column if not exists suggestions_applied boolean not null default false;

drop function public.decide_point_text_review(uuid, text, text);

create function public.decide_point_text_review(
  p_review_id uuid,
  p_decision text,
  p_decision_note text default null,
  p_apply_suggestions boolean default false
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
  v_suggestion jsonb;
  v_field text;
  v_line integer;
  v_lines text[];
  v_suggestions_applied boolean := false;
begin
  if coalesce(v_role, '') not in ('admin', 'temple_member') or auth.uid() is null then
    raise exception 'not authorized' using errcode = '42501';
  end if;
  if p_decision not in ('approved', 'rejected') then
    raise exception 'decision must be approved or rejected' using errcode = '22023';
  end if;
  if p_apply_suggestions and p_decision <> 'approved' then
    raise exception 'suggestions can only be applied when approving' using errcode = '22023';
  end if;
  select * into v_review from public.point_text_reviews where review_id = p_review_id for update;
  if not found or v_review.status <> 'pending' then
    raise exception 'pending review not found' using errcode = 'P0002';
  end if;
  if p_decision = 'approved' then
    v_content := v_review.proposed_content;
    if p_apply_suggestions then
      for v_suggestion in
        select value from jsonb_array_elements(v_review.suggestions) as suggestions(value)
        where value ->> 'code' = 'uppercase'
      loop
        v_field := v_suggestion ->> 'field';
        v_line := (v_suggestion ->> 'line')::integer;
        if v_field is null or v_field not in ('title', 'subtitle', 'lyrics')
           or v_line is null or v_line < 1
           or coalesce(jsonb_typeof(v_suggestion -> 'lineProposed'), '') <> 'string' then
          raise exception 'invalid capitalization suggestion' using errcode = '22023';
        end if;
        v_lines := string_to_array(coalesce(v_content ->> v_field, ''), E'\n');
        if v_line > cardinality(v_lines)
           or v_lines[v_line] is distinct from (v_suggestion ->> 'lineOriginal') then
          raise exception 'capitalization suggestion no longer matches the proposal' using errcode = '40001';
        end if;
        v_lines[v_line] := v_suggestion ->> 'lineProposed';
        v_content := jsonb_set(v_content, array[v_field], to_jsonb(array_to_string(v_lines, E'\n')), true);
        v_suggestions_applied := true;
      end loop;
      if not v_suggestions_applied then
        raise exception 'no supported capitalization suggestions found' using errcode = '22023';
      end if;
    end if;
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
        title = v_content ->> 'title',
        subtitle = coalesce(v_content ->> 'subtitle', ''),
        lyrics = coalesce(v_content ->> 'lyrics', ''),
        category = case when category is not distinct from v_review.original_content ->> 'category'
          then v_content ->> 'category' else category end,
        work_group = case when work_group is not distinct from v_review.original_content ->> 'work_group'
          then v_content ->> 'work_group' else work_group end,
        source = case when source is not distinct from v_review.original_content ->> 'source'
          then coalesce(v_content ->> 'source', '') else source end,
        video_url = case when video_url is not distinct from v_review.original_content ->> 'video_url'
          then coalesce(v_content ->> 'video_url', '') else video_url end,
        audio_url = case when audio_url is not distinct from v_review.original_content ->> 'audio_url'
          then coalesce(v_content ->> 'audio_url', '') else audio_url end
      where id = v_review.point_id
        and is_deleted = false
        and title is not distinct from v_review.original_content ->> 'title'
        and subtitle is not distinct from v_review.original_content ->> 'subtitle'
        and lyrics is not distinct from v_review.original_content ->> 'lyrics';
      if not found then
        if exists (select 1 from public.points where id = v_review.point_id and is_deleted = true) then
          raise exception 'inactive points cannot be reactivated by text review approval' using errcode = '55000';
        end if;
        raise exception 'point text changed after this review was submitted; reject and resubmit against the current text' using errcode = '40001';
      end if;
    end if;
  end if;
  update public.point_text_reviews set
    status = p_decision,
    decided_by = auth.uid(),
    decided_at = now(),
    decision_note = coalesce(nullif(btrim(p_decision_note), ''), case when v_suggestions_applied then 'Sugestão de capitalização aplicada' end),
    approved_content = case when p_decision = 'approved' then v_content else null end,
    suggestions_applied = v_suggestions_applied
  where review_id = p_review_id;
end;
$$;

revoke all on function public.decide_point_text_review(uuid, text, text, boolean) from public, anon;
grant execute on function public.decide_point_text_review(uuid, text, text, boolean) to authenticated;
notify pgrst, 'reload schema';