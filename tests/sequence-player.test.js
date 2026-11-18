const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const player = require('../sequence-player.js');

const points = [
  { id: 'a', title: 'Um', category: 'Ogum', group: 'Orixás', audioUrl: 'https://cdn.example/a.mp3' },
  { id: 'b', title: 'Sem áudio', category: 'Ogum', group: 'Orixás' },
  { id: 'c', title: 'Outro', category: 'Oxalá', group: 'Orixás', audio_url: 'https://cdn.example/c.ogg' },
  { id: 'd', title: 'Pendente', category: 'Ogum', group: 'Orixás', audioUrl: 'https://cdn.example/d.mp3', isDraft: true },
  { id: 'e', title: 'Removido', category: 'Ogum', group: 'Orixás', audioUrl: 'https://cdn.example/e.mp3', is_deleted: true },
  { id: 'f', title: 'Vídeo', category: 'Ogum', group: 'Orixás', videoUrl: 'https://youtube.com/watch?v=abcdefghijk' },
  { id: 'g', title: 'Vídeo pela fonte', category: 'Oxalá', group: 'Orixás', videoUrl: '', source: 'https://youtu.be/lmnopqrstuv' },
  { id: 'h', title: 'Spotify', category: 'Ogum', group: 'Orixás', spotifyUrl: 'https://open.spotify.com/track/5LNAFXRwufCwNphMKiix3v' },
];

test('category and line queues include only published points with direct audio', () => {
  assert.deepEqual(player.buildQueue(points, 'category', 'Ogum').map(point => point.id), ['a']);
  assert.deepEqual(player.buildQueue(points, 'line', 'Orixás').map(point => point.id), ['a', 'c']);
});

test('custom queue preserves selected order and drops unavailable or unpublished points', () => {
  assert.deepEqual(player.buildQueue(points, 'custom', null, ['c', 'b', 'd', 'a']).map(point => point.id), ['c', 'a']);
});

test('previous and next stay within queue bounds', () => {
  const queue = player.buildQueue(points, 'line', 'Orixás');
  assert.equal(player.nextIndex(queue, 0, -1), -1);
  assert.equal(player.nextIndex(queue, 0, 1), 1);
  assert.equal(player.nextIndex(queue, 1, 1), -1);
});

test('YouTube links in either video or source fields are selectable media', () => {
  assert.equal(player.youtubeVideoId(points[5]), 'abcdefghijk');
  assert.equal(player.youtubeVideoId(points[6]), 'lmnopqrstuv');
  assert.deepEqual(player.buildMediaQueue(points, 'category', 'Ogum').map(point => point.id), ['a', 'f', 'h']);
  assert.deepEqual(player.buildMediaQueue(points, 'all').map(point => point.id), ['a', 'c', 'f', 'g', 'h']);
});

test('custom media queue keeps order and omits drafts, deleted points and points without media', () => {
  assert.deepEqual(player.buildMediaQueue(points, 'custom', null, ['g', 'b', 'd', 'f', 'a']).map(point => point.id), ['g', 'f', 'a']);
});

test('the point dialog contains a selectable track control wired to playback', () => {
  const app = fs.readFileSync(require.resolve('../app.js'), 'utf8');
  const html = fs.readFileSync(require.resolve('../index.html'), 'utf8');
  assert.match(html, /id="sequence-track-select"[^>]*aria-label="Selecionar ponto para reproduzir"/);
  assert.match(app, /function playSelectedSequencePoint\(id\)/);
  assert.match(app, /#sequence-track-select'\)\.addEventListener\('change',event=>playSelectedSequencePoint/);
  assert.match(app, /if\(!keepPlayerDock\)\{prepareSequenceForPoint\(p\);const sequencePlayer=.*appendChild\(sequencePlayer\);\}dialog\.showModal\(\)/);
});

test('catalog card opens its media detail and can separately start the bottom player', () => {
  const app = fs.readFileSync(require.resolve('../app.js'), 'utf8');
  const html = fs.readFileSync(require.resolve('../index.html'), 'utf8');
  assert.match(app, /openPoint\(card\.dataset\.id,\{keepPlayerDock:true\}\)/);
  assert.match(app, /data-open-point="\$\{esc\(p\.id\)\}"/);
  assert.match(app, /selectPointForPlayback\(points\.find\(point=>point\.id===b\.dataset\.openPoint\)\)/);
  assert.match(app, /function selectPointForPlayback\(point,preference='auto'\)/);
  assert.match(app, /trackSelect\.hidden=sequenceQueue\.length<1/);
  assert.match(app, /function loadYoutubeMiniVideo\(videoId\)/);
  assert.match(app, /sequence-open-point.*showSequenceLyrics\(sequenceQueue\[sequenceIndex\]\)/);
  assert.match(html, /id="sequence-youtube-host"/);
  assert.match(html, /id="sequence-prompt"/);
  assert.match(html, /id="sequence-lyrics-panel"/);
  assert.match(html, /option value="all">Todos os pontos/);
});

test('Spotify track links are parsed and included in the shared media queue',()=>{assert.equal(player.spotifyTrackId(points[7]),'5LNAFXRwufCwNphMKiix3v');assert.equal(player.hasPlayableSpotify(points[7]),true);assert.equal(player.hasPlayableAudio(points[7]),false);assert.equal(player.preferredMediaType(points[7],'spotify'),'spotify');
  assert.equal(player.preferredMediaType(points[7],'auto'),'');
  assert.equal(player.preferredMediaType(points[5],'youtube'),'youtube');
  assert.equal(player.preferredMediaType(points[0],''),'');assert.equal(player.preferredMediaType(points[7],'youtube'),'');assert.deepEqual(player.buildMediaQueue(points,'category','Ogum').map(p=>p.id),['a','f','h']);});
test('Spotify parser rejects album, playlist and unrelated URLs',()=>{assert.equal(player.spotifyTrackId({spotifyUrl:'https://open.spotify.com/album/5LNAFXRwufCwNphMKiix3v'}),'');assert.equal(player.spotifyTrackId({spotifyUrl:'https://open.spotify.com/playlist/5LNAFXRwCwNphMKiix3v'}),'');assert.equal(player.spotifyTrackId({spotifyUrl:'https://example.com/track/5LNAFXRwufCwNphMKiix3v'}),'');});

test('automatic preference never chooses a platform; explicit selection is required',()=>{
 const both={videoUrl:'https://youtu.be/abcdefghijk',spotifyUrl:'https://open.spotify.com/track/5LNAFXRwufCwNphMKiix3v',audioUrl:'https://cdn.example/song.mp3'};
 assert.equal(player.preferredMediaType(both,'auto'),'');
 assert.equal(player.preferredMediaType(both,''),'');
 assert.equal(player.preferredMediaType(both,'youtube'),'youtube');
 assert.equal(player.preferredMediaType(both,'spotify'),'spotify');
 assert.equal(player.preferredMediaType(both,'audio'),'audio');
 assert.equal(player.preferredMediaType({...both,videoUrl:''},'youtube'),'');
});
test('application provides manual platform choices and retains preference until changed',()=>{
 const app=fs.readFileSync(require.resolve('../app.js'),'utf8'),html=fs.readFileSync(require.resolve('../index.html'),'utf8');
 assert.match(app,/function chooseSequencePlatform\(type\)/);
 assert.match(app,/function renderSequencePlatformOptions\(point\)/);
 assert.doesNotMatch(app,/sequenceMediaPreference='auto'/);
 assert.match(app,/id="play-youtube-point"/);
 assert.match(app,/id="play-spotify-point"/);
 assert.match(html,/id="sequence-platform-options"/);
});
