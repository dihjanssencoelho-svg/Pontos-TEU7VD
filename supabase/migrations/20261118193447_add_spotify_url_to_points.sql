alter table public.points add column if not exists spotify_url text not null default '';
do $$
begin
 if not exists(select 1 from pg_constraint where conname='points_spotify_url_format_check' and conrelid='public.points'::regclass) then
  alter table public.points add constraint points_spotify_url_format_check check (spotify_url='' or spotify_url ~* '^https://open\.spotify\.com/(intl-[a-z]{2}/)?track/[A-Za-z0-9]{22}([?].*)?$');
 end if;
end $$;
create or replace function public.update_point_spotify_url(p_point_id text,p_spotify_url text default '')
returns void language plpgsql security definer set search_path=''
as $$
declare v_role text:=auth.jwt()->'app_metadata'->>'role'; v_url text:=coalesce(btrim(p_spotify_url),'');
begin
 if coalesce(v_role,'') not in ('admin','temple_member') or auth.uid() is null then raise exception 'not authorized' using errcode='42501'; end if;
 if v_url<>'' and v_url !~* '^https://open\.spotify\.com/(intl-[a-z]{2}/)?track/[A-Za-z0-9]{22}([?].*)?$' then raise exception 'invalid Spotify track URL' using errcode='22023'; end if;
 update public.points set spotify_url=v_url where id=p_point_id and is_deleted=false;
 if not found then raise exception 'active point not found' using errcode='P0002'; end if;
end $$;
revoke all on function public.update_point_spotify_url(text,text) from public,anon;
grant execute on function public.update_point_spotify_url(text,text) to authenticated;
update public.points set spotify_url='https://open.spotify.com/track/5LNAFXRwufCwNphMKiix3v' where id='iansa-oya' and is_deleted=false and coalesce(spotify_url,'')='';
update public.points set spotify_url='https://open.spotify.com/track/1C21bzwjIvVzkMiqRa1hvD' where id='iemanja-pedido' and is_deleted=false and coalesce(spotify_url,'')='';
