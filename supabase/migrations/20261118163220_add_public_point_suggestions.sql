-- Public suggestions are kept separate from the published catalog.
create table public.point_suggestions (
  id uuid primary key,
  name text,
  category text not null,
  work_group text not null,
  lyrics text not null,
  youtube_url text,
  voice_path text,
  submitted_at timestamptz not null default now(),
  constraint point_suggestions_name_length check (name is null or char_length(name) <= 120),
  constraint point_suggestions_lyrics_length check (char_length(lyrics) between 1 and 15000),
  constraint point_suggestions_work_group check (
    (work_group = 'Orixás' and category in ('Oxalá','Ogum','Oxóssi','Xangô','Iansã','Oxum','Iemanjá','Obaluaê','Omolu','Nanã','Obá','Logunan','Oroiná','Oxumaré'))
    or (work_group = 'Linhas de trabalho' and category in ('Erês / Ibejada','Caboclos','Pretos Velhos','Baianos','Marinheiros','Boiadeiros','Exus','Malandros','Pombagiras','Exu Mirim','Pombogira Mirim','Ciganos'))
    or (work_group = 'Ritualística' and category in ('Defumação','Abertura'))
  ),
  constraint point_suggestions_youtube_url check (
    youtube_url is null or youtube_url ~* '^https?://(www\.)?(youtube\.com|youtu\.be)/'
  )
);

alter table public.point_suggestions enable row level security;
revoke all on public.point_suggestions from anon, authenticated;
grant insert (id, name, category, work_group, lyrics, youtube_url) on public.point_suggestions to anon, authenticated;
grant select on public.point_suggestions to authenticated;

create policy "Anyone can submit a point suggestion"
  on public.point_suggestions for insert to anon, authenticated
  with check (voice_path is null);
create policy "Temple editors can read point suggestions"
  on public.point_suggestions for select to authenticated
  using ((select auth.jwt() -> 'app_metadata' ->> 'role') in ('admin', 'temple_member'));

-- A private bucket limits uploads to one small audio file under a UUID path.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'point-suggestion-voice',
  'point-suggestion-voice',
  false,
  15728640,
  array['audio/mpeg','audio/mp4','audio/x-m4a','audio/wav','audio/x-wav','audio/ogg','audio/webm','audio/aac']
);

create policy "Anyone can upload a point suggestion voice recording"
  on storage.objects for insert to anon, authenticated
  with check (
    bucket_id = 'point-suggestion-voice'
    and (storage.foldername(name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and storage.filename(name) = 'voice'
  );
create policy "Temple editors can listen to suggested voice recordings"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'point-suggestion-voice'
    and (select auth.jwt() -> 'app_metadata' ->> 'role') in ('admin', 'temple_member')
  );

create or replace function public.attach_point_suggestion_voice(p_suggestion_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_path text := p_suggestion_id::text || '/voice';
begin
  if not exists (
    select 1 from storage.objects
    where bucket_id = 'point-suggestion-voice' and name = v_path
  ) then
    raise exception 'voice recording not found' using errcode = 'P0002';
  end if;

  update public.point_suggestions
  set voice_path = v_path
  where id = p_suggestion_id and voice_path is null;

  if not found and not exists (
    select 1 from public.point_suggestions where id = p_suggestion_id and voice_path = v_path
  ) then
    raise exception 'point suggestion not found' using errcode = 'P0002';
  end if;
end;
$$;

revoke all on function public.attach_point_suggestion_voice(uuid) from public;
grant execute on function public.attach_point_suggestion_voice(uuid) to anon, authenticated;
notify pgrst, 'reload schema';
