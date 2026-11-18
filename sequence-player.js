(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  if (root) root.PointSequencePlayer = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  function hasPlayableAudio(point) {
    const value = String(point?.audioUrl || point?.audio_url || '').trim();
    if (!value) return false;
    try {
      const url = new URL(value);
      return ['http:', 'https:'].includes(url.protocol) && !/(youtube\.com|youtu\.be|spotify\.com)/i.test(url.hostname);
    } catch { return false; }
  }

  function youtubeVideoId(point) {
    for (const value of [point?.videoUrl, point?.video_url, point?.source]) {
      if (!value) continue;
      try {
        const url = new URL(String(value).trim());
        const host = url.hostname.toLowerCase().replace(/^www\./, '');
        let id = '';
        if (host === 'youtu.be') id = url.pathname.split('/').filter(Boolean)[0] || '';
        else if (['youtube.com', 'm.youtube.com', 'youtube-nocookie.com'].includes(host)) {
          if (url.pathname === '/watch') id = url.searchParams.get('v') || '';
          else if (['/embed/', '/shorts/', '/live/'].some(prefix => url.pathname.startsWith(prefix))) id = url.pathname.split('/')[2] || '';
        }
        if (/^[A-Za-z0-9_-]{11}$/.test(id)) return id;
      } catch { /* Try the next registered media field. */ }
    }
    return '';
  }

  function hasPlayableMedia(point) {
    return hasPlayableAudio(point) || !!youtubeVideoId(point);
  }

  function buildQueue(points, mode, selected, customIds = [], media = 'audio') {
    const visible = (points || []).filter(point => point.isDeleted !== true && point.is_deleted !== true && !point.isDraft);
    let scoped = visible;
    if (mode === 'category') scoped = visible.filter(point => point.category === selected);
    if (mode === 'line') scoped = visible.filter(point => point.group === selected || point.work_group === selected);
    if (mode === 'all') scoped = visible;
    if (mode === 'custom') {
      const byId = new Map(visible.map(point => [point.id, point]));
      scoped = customIds.map(id => byId.get(id)).filter(Boolean);
    }
    return scoped.filter(media === 'media' ? hasPlayableMedia : hasPlayableAudio);
  }

  function buildMediaQueue(points, mode, selected, customIds = []) {
    return buildQueue(points, mode, selected, customIds, 'media');
  }

  function nextIndex(queue, currentIndex, direction = 1) {
    const next = currentIndex + direction;
    return next >= 0 && next < queue.length ? next : -1;
  }

  return { hasPlayableAudio, hasPlayableMedia, youtubeVideoId, buildQueue, buildMediaQueue, nextIndex };
});
