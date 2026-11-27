const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const source = fs.readFileSync(path.join(__dirname, '../assets/score/score.js'), 'utf8');

function start(preview) {
  const notifications = [], tasks = [], scripts = [], elements = new Map(), layouts = [];
  const context = {
    console: { error() {} }, TextDecoder, Uint8Array,
    atob: value => Buffer.from(value, 'base64').toString('binary'),
    requestAnimationFrame: callback => tasks.push(callback),
    DOMParser: class { parseFromString() { return {
      documentElement: { localName: 'score-partwise', children: [] },
      getElementsByTagName: () => [],
    }; } },
    XMLSerializer: class { serializeToString() { return '<score-partwise/>'; } },
    document: {
      getElementById(id) {
        if (!elements.has(id)) elements.set(id, { addEventListener() {} });
        return elements.get(id);
      },
      body: { classList: { toggle() {} } },
      createElement: () => ({}), head: { appendChild: script => scripts.push(script) },
    },
    window: {
      ScoreStatus: { postMessage: message => notifications.push(message) },
      setTimeout: callback => tasks.push(callback),
    },
    verovio: { module: {}, toolkit: class {
      setOptions(options) { layouts.push(options); }
      loadData() { return true; }
      getPageCount() { return 2; }
      renderToSVG() { return '<svg width="1200"></svg>'; }
    } },
  };
  vm.runInNewContext(source, context);
  assert.deepEqual(notifications, ['ready'], 'Bridge must be ready before loading the engine');
  assert.equal(scripts.length, 0);
  for (const [kind, value] of [
    ['score', '<score-partwise/>'], ['timeline', '[]'],
    ...(preview ? [['preview', preview]] : []),
  ]) context.window.HarmoniaScore.append(kind, Buffer.from(value).toString('base64'));
  context.window.HarmoniaScore.load(true);
  return { context, notifications, tasks, scripts, elements, layouts };
}

const cold = start();
cold.scripts[0].onload();
for (const task of cold.tasks) task();
assert.deepEqual(cold.notifications, ['ready'], 'Slow initialization must not be a permanent error');
cold.context.verovio.module.onRuntimeInitialized();
assert(cold.notifications.includes('loaded'));
assert.equal(cold.layouts[0].pageWidth, 1500);
assert.equal(cold.layouts[0].lyricWordSpace, 4.5);
assert(cold.notifications.some(message => message.startsWith('preview:{"version":2,')));
assert.equal(cold.notifications.at(-1), 'engraved');
cold.context.verovio.module.onAbort();
assert.equal(cold.notifications.at(-1), 'error', 'Actual engine failure must be reported');

const warm = start(JSON.stringify({ version: 2, svg: '<svg width="1500"></svg>', pageCount: 2 }));
assert.deepEqual(warm.notifications, ['ready', 'loaded']);
assert.equal(warm.scripts.length, 0, 'Cached sheet must paint before loading the large engine script');
assert.equal(warm.elements.get('next').disabled, true);
for (const task of warm.tasks) task();
warm.tasks.length = 0;
warm.scripts[0].onload();
warm.context.verovio.module.onRuntimeInitialized();
for (const task of warm.tasks) task();
assert.equal(warm.elements.get('next').disabled, false);
assert.equal(warm.notifications.at(-1), 'engraved');

const old = start(JSON.stringify({ version: 1, svg: '<svg width="1200"></svg>', pageCount: 2 }));
assert.deepEqual(old.notifications, ['ready'], 'Older previews must not display the previous layout');
old.scripts[0].onload();
old.context.verovio.module.onRuntimeInitialized();
assert(old.notifications.some(message => message.startsWith('preview:{"version":2,')));

const corrupt = start('{invalid preview');
corrupt.scripts[0].onload();
corrupt.context.verovio.module.onRuntimeInitialized();
assert(corrupt.notifications.includes('loaded'), 'Corrupt previews must use the verified score');
console.log('Score startup, preview and fallback checks passed');
