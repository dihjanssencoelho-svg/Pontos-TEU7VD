(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  if (root) root.PointTextReview = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  const TEXT_FIELDS = ['title', 'subtitle', 'lyrics'];
  const PROTECTED_TERMS = new Set([
    'oxala', 'ogum', 'oxossi', 'xango', 'iansa', 'oya', 'oxum', 'iemanja',
    'obaluae', 'omolu', 'nana', 'oba', 'logunan', 'oroina', 'oxumare',
    'atoto', 'sarava', 'okearo', 'exu', 'pombagira', 'pretovelho', 'caboclo',
    'yoruba', 'yorubas', 'orixa', 'orixas', 'oga', 'ogas'
  ]);
  const SPELLING_HINTS = new Map([
    ['voce', 'você'], ['voces', 'vocês'], ['tambem', 'também'],
    ['ninguem', 'ninguém'], ['coracao', 'coração'], ['coracoes', 'corações'],
    ['bencao', 'bênção'], ['bencaos', 'bênçãos'], ['fe', 'fé'],
    ['agua', 'água'], ['aguas', 'águas'], ['mae', 'mãe'], ['maes', 'mães']
  ]);

  function inspect(text) {
    const lines = String(text ?? '').replace(/\r\n?/g, '\n').split('\n');
    const suggestions = [];
    const add = (type, field, line, original, proposed, message) => {
      suggestions.push({ type, field, line, original, proposed, message });
    };
    lines.forEach((line, index) => {
      const lineNumber = index + 1;
      const caseProbe = line.replace(/\(\s*x\s*\d+\s*\)/giu, '');
      const letters = caseProbe.match(/[\p{L}]/gu) || [];
      if (letters.length >= 3 && letters.every(letter => letter === letter.toLocaleUpperCase('pt-BR'))) {
        const normalized = line.toLocaleLowerCase('pt-BR').replace(/[\p{L}]+/gu, (word, offset) => {
          const key = word.normalize('NFD').replace(/[\u0300-\u036f]/g, '');
          const firstWord = !line.slice(0, offset).match(/[\p{L}]/u);
          return firstWord || PROTECTED_TERMS.has(key)
            ? word[0].toLocaleUpperCase('pt-BR') + word.slice(1)
            : word;
        });
        add('deterministic', 'lyrics', lineNumber, line, normalized, 'Texto em letras maiúsculas. Confira a sugestão de capitalização.');
        suggestions[suggestions.length - 1].code = 'uppercase';
        suggestions[suggestions.length - 1].lineOriginal = line;
        suggestions[suggestions.length - 1].lineProposed = normalized;
      }
      if (/[ \t]+$/.test(line)) add('deterministic', 'lyrics', lineNumber, line, line.replace(/[ \t]+$/, ''), 'Espaços no fim do verso.');
      if (/ {2,}/.test(line)) add('deterministic', 'lyrics', lineNumber, line, line.replace(/ {2,}/g, ' '), 'Espaços repetidos entre palavras.');
      if (/\s+[,.!?;:]/.test(line)) add('deterministic', 'lyrics', lineNumber, line, line.replace(/\s+([,.!?;:])/g, '$1'), 'Espaço antes da pontuação.');
      for (const match of line.matchAll(/[\p{L}]+/gu)) {
        const original = match[0];
        const key = original.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLocaleLowerCase('pt-BR');
        if (PROTECTED_TERMS.has(key)) continue;
        const candidate = SPELLING_HINTS.get(key);
        if (!candidate) continue;
        const replacement = original[0] === original[0].toLocaleUpperCase('pt-BR')
          ? candidate[0].toLocaleUpperCase('pt-BR') + candidate.slice(1)
          : candidate;
        const proposed = line.slice(0, match.index) + replacement + line.slice(match.index + original.length);
        add('assisted', 'lyrics', lineNumber, original, replacement, `Confira a acentuação sugerida: “${original}” → “${replacement}”.`);
        suggestions[suggestions.length - 1].lineOriginal = line;
        suggestions[suggestions.length - 1].lineProposed = proposed;
      }
    });
    for (let i = 1; i < lines.length; i++) {
      if (lines[i].trim() && lines[i].trim() === lines[i - 1].trim()) {
        add('deterministic', 'lyrics', i + 1, lines[i], lines[i], 'Verso repetido consecutivamente. Confira; repetições podem ser intencionais e serão preservadas.');
      }
    }
    return suggestions;
  }

  function reviewRecord(point) {
    return { title: String(point.title ?? ''), subtitle: String(point.subtitle ?? ''), lyrics: String(point.lyrics ?? '') };
  }
  function changedText(before, after) {
    return TEXT_FIELDS.some(field => String(before?.[field] ?? '') !== String(after?.[field] ?? ''));
  }
  return { TEXT_FIELDS, inspect, reviewRecord, changedText };
});