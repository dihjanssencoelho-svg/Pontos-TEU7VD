-- Keep public submissions limited to their own deterministic audio object path.
drop function public.attach_point_suggestion_voice(uuid);
drop policy "Anyone can submit a point suggestion" on public.point_suggestions;
create policy "Anyone can submit a point suggestion"
  on public.point_suggestions for insert to anon, authenticated
  with check (voice_path is null or voice_path = id::text || '/voice');
grant insert (voice_path) on public.point_suggestions to anon, authenticated;
