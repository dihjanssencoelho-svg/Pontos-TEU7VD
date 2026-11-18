create table if not exists public.spotify_match_reviews (
  review_id uuid primary key default gen_random_uuid(),
  point_id text not null references public.points(id) on delete cascade,
  candidate_title text not null,
  artist text not null default '',
  spotify_url text not null,
  evidence_url text not null default '',
  match_basis text not null default 'exact_title',
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  submitted_at timestamptz not null default now(),
  decided_by uuid references auth.users(id),
  decided_at timestamptz,
  decision_note text,
  constraint spotify_match_reviews_track_url_check check (spotify_url ~* '^https://open[.]spotify[.]com/(intl-[a-z]{2}/)?track/[A-Za-z0-9]{22}([?].*)?)
);
create index if not exists spotify_match_reviews_status_submitted_idx on public.spotify_match_reviews(status, submitted_at desc);
create unique index if not exists spotify_match_reviews_pending_unique on public.spotify_match_reviews(point_id, spotify_url) where status='pending';
alter table public.spotify_match_reviews enable row level security;
drop policy if exists "Temple editors can read Spotify match reviews" on public.spotify_match_reviews;
create policy "Temple editors can read Spotify match reviews" on public.spotify_match_reviews for select to authenticated using ((select auth.jwt()->'app_metadata'->>'role') in ('admin','temple_member'));
drop policy if exists "Site admins can manage Spotify match reviews" on public.spotify_match_reviews;
create policy "Site admins can manage Spotify match reviews" on public.spotify_match_reviews for all to authenticated using ((select auth.jwt()->'app_metadata'->>'role')='admin') with check ((select auth.jwt()->'app_metadata'->>'role')='admin');
revoke all on public.spotify_match_reviews from anon, public;
grant select on public.spotify_match_reviews to authenticated;
grant insert, update, delete on public.spotify_match_reviews to authenticated;
)
);
create index if not exists spotify_match_reviews_status_submitted_idx on public.spotify_match_reviews(status, submitted_at desc);
create unique index if not exists spotify_match_reviews_pending_unique on public.spotify_match_reviews(point_id, spotify_url) where status='pending';
alter table public.spotify_match_reviews enable row level security;
drop policy if exists "Temple editors can read Spotify match reviews" on public.spotify_match_reviews;
create policy "Temple editors can read Spotify match reviews" on public.spotify_match_reviews for select to authenticated using ((select auth.jwt()->'app_metadata'->>'role') in ('admin','temple_member'));
drop policy if exists "Site admins can manage Spotify match reviews" on public.spotify_match_reviews;
create policy "Site admins can manage Spotify match reviews" on public.spotify_match_reviews for all to authenticated using ((select auth.jwt()->'app_metadata'->>'role')='admin') with check ((select auth.jwt()->'app_metadata'->>'role')='admin');
revoke all on public.spotify_match_reviews from anon, public;
grant select on public.spotify_match_reviews to authenticated;
grant insert, update, delete on public.spotify_match_reviews to authenticated;
