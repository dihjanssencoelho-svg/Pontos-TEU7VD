create or replace function public.decide_spotify_match_review(p_review_id uuid,p_decision text,p_decision_note text default null)
returns void language plpgsql security invoker set search_path=''
as $$
declare v_role text:=auth.jwt()->'app_metadata'->>'role'; v_review public.spotify_match_reviews%rowtype;
begin
 if auth.uid() is null or coalesce(v_role,'') <> 'admin' then raise exception 'not authorized' using errcode='42501'; end if;
 if p_decision not in ('approved','rejected') then raise exception 'invalid decision' using errcode='22023'; end if;
 select * into v_review from public.spotify_match_reviews where review_id=p_review_id and status='pending' for update;
 if not found then raise exception 'pending Spotify review not found' using errcode='P0002'; end if;
 if p_decision='approved' then
   perform public.update_point_spotify_url(v_review.point_id,v_review.spotify_url);
 end if;
 update public.spotify_match_reviews
 set status=p_decision,decided_by=auth.uid(),decided_at=now(),decision_note=nullif(btrim(p_decision_note),'')
 where review_id=p_review_id;
end;
$$;
revoke all on function public.decide_spotify_match_review(uuid,text,text) from public, anon;
grant execute on function public.decide_spotify_match_review(uuid,text,text) to authenticated;
