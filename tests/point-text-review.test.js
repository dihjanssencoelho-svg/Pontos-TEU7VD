const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const review = require('../text-review.js');

test('mechanical checks suggest whitespace cleanup without changing the source', () => {
  const source = '  Saravá,  Oxalá!  ';
  const suggestions = review.inspect(source);
  assert.ok(suggestions.some(item => item.type === 'deterministic' && item.message.includes('Espaços repetidos')));
  assert.equal(source, '  Saravá,  Oxalá!  ');
});

test('assisted spelling suggestions stay suggestions and do not rewrite sacred names', () => {
  const suggestions = review.inspect('Voce viu Oxala e Ogum?');
  assert.ok(suggestions.some(item => item.type === 'assisted' && item.proposed === 'Você'));
  assert.ok(!suggestions.some(item => item.original === 'Oxala' || item.original === 'Ogum'));
});

test('consecutive repeated verses are flagged without being removed', () => {
  const suggestions = review.inspect('Eu vou cantar\nEu vou cantar');
  const repeated = suggestions.find(item => item.message.includes('repetido consecutivamente'));
  assert.ok(repeated);
  assert.equal(repeated.proposed, 'Eu vou cantar');
});

test('text change detection ignores unrelated metadata but detects lyrics edits', () => {
  assert.equal(review.changedText({ title: 'A', lyrics: 'x' }, { title: 'A', lyrics: 'x', category: 'Ogum' }), false);
  assert.equal(review.changedText({ title: 'A', lyrics: 'x' }, { title: 'A', lyrics: 'y' }), true);
});

test('migration does not backfill points or modify the protected backup', () => {
  const sql = fs.readFileSync(path.join(__dirname, '../supabase/migrations/20261116150000_add_point_text_review_workflow.sql'), 'utf8');
  assert.match(sql, /security definer[\s\S]*set search_path = ''/i);
  assert.match(sql, /unique index if not exists point_text_reviews_one_pending_per_point_idx/i);
  assert.doesNotMatch(sql, /(?:insert|update|delete)\s+(?:into\s+|from\s+)?public\.points_text_review_backup_20261113/i);
  const hardening = fs.readFileSync(path.join(__dirname, '../supabase/migrations/20261116150100_lock_point_writes_to_review_rpcs.sql'), 'utf8');
  assert.match(hardening, /revoke all on public\.points from anon, authenticated/i);
  assert.match(hardening, /grant select on public\.points to anon, authenticated/i);
});

test('catalog writes use the review and deletion RPCs instead of direct point writes', () => {
  const app = fs.readFileSync(path.join(__dirname, '../app.js'), 'utf8');
  assert.match(app, /rpc\('submit_point_text_review'/);
  assert.match(app, /rpc\('decide_point_text_review'/);
  assert.match(app, /rpc\('update_point_metadata'/);
  assert.match(app, /rpc\('soft_delete_point'/);
  assert.doesNotMatch(app, /from\(['"]points['"]\)\.(?:insert|update|upsert|delete)\(/);
});

test('approval refuses stale text and never reactivates an inactive point', () => {
  const sql = fs.readFileSync(path.join(__dirname, '../supabase/migrations/20261116150000_add_point_text_review_workflow.sql'), 'utf8');
  assert.match(sql, /and is_deleted = false[\s\S]*and title is not distinct from v_review\.original_content[\s\S]*and lyrics is not distinct from v_review\.original_content/i);
  assert.match(sql, /inactive points cannot be reactivated by text review approval/i);
  assert.match(sql, /category = case when category is not distinct from v_review\.original_content/i);
  assert.doesNotMatch(sql, /is_deleted\s*=\s*false\s*where id = v_review\.point_id/i);
});

test('both existing editor roles retain decision access and metadata edits remain available during review', () => {
  const sql = fs.readFileSync(path.join(__dirname, '../supabase/migrations/20261116150000_add_point_text_review_workflow.sql'), 'utf8');
  assert.equal((sql.match(/coalesce\(v_role, ''\) not in \('admin', 'temple_member'\)/g) || []).length, 4);
  const metadataRpc = sql.split('create or replace function public.update_point_metadata')[1];
  assert.ok(metadataRpc);
  assert.doesNotMatch(metadataRpc, /point_text_reviews/i);
});
