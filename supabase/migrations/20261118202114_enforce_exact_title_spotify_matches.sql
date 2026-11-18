create or replace function public.enforce_exact_spotify_match_title()
returns trigger language plpgsql security invoker set search_path=''
as $$
declare v_title text;
begin
 select title into v_title from public.points where id=new.point_id and is_deleted=false;
 if not found then raise exception 'active point not found' using errcode='P0002'; end if;
 if lower(btrim(new.candidate_title)) is distinct from lower(btrim(v_title)) then
   raise exception 'Spotify candidate title must exactly match the catalog point title (case-insensitive)' using errcode='23514';
 end if;
 return new;
end;
$$;
drop trigger if exists enforce_exact_spotify_match_title on public.spotify_match_reviews;
create trigger enforce_exact_spotify_match_title
before insert or update of point_id,candidate_title on public.spotify_match_reviews
for each row execute function public.enforce_exact_spotify_match_title();
revoke all on function public.enforce_exact_spotify_match_title() from public, anon;
