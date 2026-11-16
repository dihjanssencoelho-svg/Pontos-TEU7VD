-- Apply refreshed deterministic suggestions to a pending review without rewriting its submitted proposal.
create or replace function public.apply_point_text_review_suggestions(
  p_review_id uuid,
  p_suggestions jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role text := auth.jwt() -> 'app_metadata' ->> 'role';
  v_review public.point_text_reviews%rowtype;
  v_suggestion jsonb;
  v_field text;
  v_line integer;
  v_lines text[];
  v_applied boolean := false;
begin
  if coalesce(v_role, '') not in ('admin', 'temple_member') or auth.uid() is null then
    raise exception 'not authorized' using errcode = '42501';
  end if;
  if coalesce(jsonb_typeof(p_suggestions), '') <> 'array' then
    raise exception 'suggestions must be a JSON array' using errcode = '22023';
  end if;
  select * into v_review
    from public.point_text_reviews
    where review_id = p_review_id
    for update;
  if not found or v_review.status <> 'pending' then
    raise exception 'pending review not found' using errcode = 'P0002';
  end if;
  for v_suggestion in
    select value from jsonb_array_elements(p_suggestions) as suggestions(value)
    where value ->> 'code' = 'uppercase'
  loop
    v_field := v_suggestion ->> 'field';
    v_line := (v_suggestion ->> 'line')::integer;
    if v_field is null or v_field not in ('title', 'subtitle', 'lyrics')
       or v_line is null or v_line < 1
       or coalesce(jsonb_typeof(v_suggestion -> 'lineProposed'), '') <> 'string' then
      raise exception 'invalid capitalization suggestion' using errcode = '22023';
    end if;
    v_lines := string_to_array(coalesce(v_review.proposed_content ->> v_field, ''), E'\n');
    if v_line > cardinality(v_lines)
       or v_lines[v_line] is distinct from (v_suggestion ->> 'lineOriginal') then
      raise exception 'capitalization suggestion no longer matches the proposal' using errcode = '40001';
    end if;
    if lower(v_suggestion ->> 'lineProposed') is distinct from lower(v_lines[v_line]) then
      raise exception 'capitalization suggestion changed text beyond letter case' using errcode = '22023';
    end if;
    v_applied := true;
  end loop;
  if not v_applied then
    raise exception 'no supported capitalization suggestions found' using errcode = '22023';
  end if;
  update public.point_text_reviews
    set suggestions = p_suggestions
    where review_id = p_review_id;
  perform public.decide_point_text_review(
    p_review_id,
    'approved',
    'Sugestão de capitalização aplicada pelo revisor',
    true
  );
end;
$$;

revoke all on function public.apply_point_text_review_suggestions(uuid, jsonb) from public, anon;
grant execute on function public.apply_point_text_review_suggestions(uuid, jsonb) to authenticated;
notify pgrst, 'reload schema';