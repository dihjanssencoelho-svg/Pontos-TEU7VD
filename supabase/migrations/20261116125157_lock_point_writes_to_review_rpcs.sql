-- Apply after the review-enabled frontend is deployed.
-- RLS does not govern TRUNCATE, so remove all client table writes and keep catalog reads.
revoke all on public.points from anon, authenticated;
grant select on public.points to anon, authenticated;
