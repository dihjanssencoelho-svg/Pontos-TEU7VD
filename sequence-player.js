(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  if (root) root.PointSequencePlayer = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  function hasPlayableAudio(point) {
    const value = String(point?.audioUrl ?? point?.audio_url ?? '').trim();
    if (!value) return false;
    try {
      const url = new URL(value);
      return ['http:', 'https:'].includes(url.protocol) && !/(youtube\.com|youtu\.be|spotify\.com)/i.test(url.hostname);
    } catch { return false; }
  }

  function buildQueue(points, mode, selected, customIds = []) {
    const visible = (points || []).filter(point => point.isDeleted !== true && point.is_deleted !== true && !point.isDraft);
    let scoped = visible;
    if (mode === 'category') scoped = visible.filter(point => point.category === selected);
    if (mode === 'line') scoped = visible.filter(point => point.group === selected || point.work_group === selected);
    if (mode === 'custom') {
      const byId = new Map(visible.map(point => [point.id, point]));
      scoped = customIds.map(id => byId.get(id)).filter(Boolean);
    }
    return scoped.filter(hasPlayableAudio);
  }

  function nextIndex(queue, currentIndex, direction = 1) {
    const next = currentIndex + direction;
    return next >= 0 && next < queue.length ? next : -1;
  }

  return { hasPlayableAudio, buildQueue, nextIndex };
});
