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
  assert.match(sql, /revoke all on public\.points from anon, authenticated/i);
  assert.match(sql, /grant select on public\.points to anon, authenticated/i);
  assert.match(sql, /security definer[\s\S]*set search_path = ''/i);
  assert.match(sql, /unique index if not exists point_text_reviews_one_pending_per_point_idx/i);
  assert.doesNotMatch(sql, /(?:insert|update|delete)\s+(?:into\s+|from\s+)?public\.points_text_review_backup_20261113/i);
});

test('catalog writes use the review and deletion RPCs instead of direct point writes', () => {
  const app = fs.readFileSync(path.join(__dirname, '../app.js'), 'utf8');
  assert.match(app, /rpc\('submit_point_text_review'/);
  assert.match(app, /rpc\('decide_point_text_review'/);
  assert.match(app, /rpc\('soft_delete_point'/);
  assert.doesNotMatch(app, /from\(['"]points['"]\)\.(?:insert|update|upsert|delete)\(/);
});
