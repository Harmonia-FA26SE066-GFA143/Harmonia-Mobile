'use strict';

const sheet = document.getElementById('sheet');
const state = document.getElementById('state');
const pages = document.getElementById('pages');
const previous = document.getElementById('previous');
const next = document.getElementById('next');
const pageNumber = document.getElementById('pageNumber');
const buffers = { score: [], timeline: [], preview: [] };
const previewVersion = 2;
let toolkit;
let engineLoading = false;
let pendingSource;
let engraved = false;
let previewShown = false;
let page = 0;
let pageCount = 0;
let notes = [];
let latestEnd = [];
let highlighted = new Set();
let followedPage = 0;
let position = -1;
let followPlayback = false;

function notify(message) {
  if (window.webkit?.messageHandlers?.scoreStatus) {
    window.webkit.messageHandlers.scoreStatus.postMessage(message);
  } else {
    window.ScoreStatus?.postMessage(message);
  }
}

function showError(stage = 'runtime') {
  state.hidden = false;
  state.textContent = 'Không thể hiển thị khuông nhạc.';
  console.error('Score engraving failed at ' + stage);
  notify('error');
}

function init() {
  try {
    if (toolkit) return;
    toolkit = new verovio.toolkit();
    toolkit.setOptions({
      expandNever: true,
      breaks: 'auto',
      pageWidth: 1500,
      pageHeight: 1600,
      pageMarginLeft: 32,
      pageMarginRight: 32,
      adjustPageHeight: true,
      lyricWordSpace: 4.5,
      svgViewBox: true,
    });
    if (pendingSource) continueEngraving();
  } catch (_) {
    showError('runtime');
  }
}

function startEngine() {
  if (toolkit) return continueEngraving();
  if (engineLoading) return;
  engineLoading = true;
  const script = document.createElement('script');
  script.src = 'verovio-toolkit-wasm.js';
  script.onerror = () => showError('runtime');
  script.onload = () => {
    if (typeof verovio === 'undefined') return showError('runtime');
    if (verovio.module.calledRun) init();
    else {
      verovio.module.onRuntimeInitialized = init;
      verovio.module.onAbort = () => showError('runtime');
    }
  };
  document.head.appendChild(script);
}

function continueEngraving() {
  // Paint the cached first page before doing the full layout in the background.
  if (previewShown) requestAnimationFrame(() => window.setTimeout(engrave, 0));
  else engrave();
}

function render(target) {
  if (!engraved || target < 1 || target > pageCount || target === page) return;
  sheet.innerHTML = toolkit.renderToSVG(target);
  page = target;
  pageNumber.textContent = target + ' / ' + pageCount;
  previous.disabled = page === 1;
  next.disabled = page === pageCount;
  highlighted.clear();
  if (followPlayback) sheet.scrollTop = 0;
}

previous.addEventListener('click', () => render(page - 1));
next.addEventListener('click', () => render(page + 1));

function append(kind, encoded) {
  if (!Object.prototype.hasOwnProperty.call(buffers, kind)) return;
  const binary = atob(encoded);
  buffers[kind].push(Uint8Array.from(binary, char => char.charCodeAt(0)));
}

function read(kind) {
  const chunks = buffers[kind];
  const first = chunks[0] ?? [];
  const encoding = first[0] === 0xff || (first[0] === 60 && first[1] === 0)
    ? 'utf-16le'
    : first[0] === 0xfe || (first[0] === 0 && first[1] === 60)
      ? 'utf-16be'
      : 'utf-8';
  const decoder = new TextDecoder(encoding, { fatal: true });
  const result = chunks.map(chunk => decoder.decode(chunk, { stream: true })).join('')
    + decoder.decode();
  buffers[kind] = [];
  return result;
}

function load(follow = false) {
  let stage = 'xml';
  try {
    followPlayback = follow;
    document.body.classList.toggle('follow-playback', followPlayback);
    const source = read('score');
    if (/<!ENTITY/i.test(source)) throw new Error('Unsupported entity');
    const xml = new DOMParser().parseFromString(
      source.replace(/<!DOCTYPE\s+[^>[]*>/i, ''), 'application/xml',
    );
    if (xml.documentElement.localName !== 'score-partwise' ||
        xml.getElementsByTagName('parsererror').length) {
      throw new Error('Invalid MusicXML');
    }

    const ids = new Map();
    let sequence = 0;
    for (const part of children(xml.documentElement, 'part')) {
      const partId = part.getAttribute('id');
      children(part, 'measure').forEach((measure, measureIndex) => {
        children(measure, 'note').forEach((note, noteIndex) => {
          const id = 'harmonia-score-n' + sequence++;
          note.setAttribute('id', id);
          ids.set([partId, measureIndex, noteIndex].join(':'), id);
        });
      });
    }
    pendingSource = new XMLSerializer().serializeToString(xml);

    stage = 'timeline';
    notes = JSON.parse(read('timeline')).flatMap(([locator, start, end]) => {
      const id = ids.get(locator);
      if (!id) return [];
      return [{ id, start, end }];
    }).sort((a, b) => a.start - b.start);
    let maxEnd = 0;
    latestEnd = notes.map(note => (maxEnd = Math.max(maxEnd, note.end)));
    if (buffers.preview.length) {
      try {
        const preview = JSON.parse(read('preview'));
        if (preview.version === previewVersion && Number.isInteger(preview.pageCount) &&
            preview.pageCount > 0 && typeof preview.svg === 'string' &&
            preview.svg.trimStart().startsWith('<svg ')) {
          sheet.innerHTML = preview.svg;
          page = 1;
          pageCount = preview.pageCount;
          pageNumber.textContent = '1 / ' + pageCount;
          previous.disabled = true;
          next.disabled = true;
          state.hidden = true;
          pages.hidden = pageCount === 1;
          previewShown = true;
          notify('loaded');
        }
      } catch (_) {
        // A missing/outdated preview falls back to the verified MusicXML.
      }
    }
    if (previewShown) requestAnimationFrame(() => window.setTimeout(startEngine, 0));
    else startEngine();
  } catch (_) {
    showError(stage);
  }
}

function engrave() {
  try {
    if (!toolkit.loadData(pendingSource)) throw new Error('Invalid score');
    pendingSource = null;
    pageCount = toolkit.getPageCount();
    if (pageCount < 1) throw new Error('No engraving pages');
    engraved = true;
    render(1);
    state.hidden = true;
    pages.hidden = pageCount === 1;
    next.disabled = page === pageCount;
    if (!previewShown) {
      notify('loaded');
      const preview = JSON.stringify({ version: previewVersion, svg: sheet.innerHTML, pageCount });
      if (preview.length <= 2 * 1024 * 1024) {
        for (let offset = 0; offset < preview.length;) {
          let end = Math.min(offset + 24 * 1024, preview.length);
          const last = preview.charCodeAt(end - 1);
          if (last >= 0xd800 && last <= 0xdbff) end--;
          notify('preview:' + preview.slice(offset, end));
          offset = end;
        }
        notify('preview-done');
      }
    }
    const currentPosition = position;
    position = -1;
    if (currentPosition >= 0) progress(currentPosition);
    notify('engraved');
  } catch (_) {
    showError('engraving');
  }
}

function children(element, name) {
  return Array.from(element.children).filter(child => child.localName === name);
}

function progress(seconds) {
  if (!pageCount || position === seconds) return;
  position = seconds;
  let lo = 0;
  let hi = latestEnd.length;
  while (lo < hi) {
    const mid = (lo + hi) >>> 1;
    if (latestEnd[mid] <= seconds) lo = mid + 1;
    else hi = mid;
  }
  const active = [];
  for (let i = lo; i < notes.length && notes[i].start <= seconds; i++) {
    if (notes[i].end > seconds) active.push(notes[i]);
  }
  const latestStart = active[active.length - 1]?.start;
  const focus = followPlayback ? active.find(note => note.start === latestStart) : active[0];
  const target = focus && (document.getElementById(focus.id) ? page :
    engraved ? toolkit.getPageWithElement(focus.id) : 0);
  if (target && target !== (followPlayback ? page : followedPage)) render(target);
  followedPage = target;
  const current = new Set(active.map(note => document.getElementById(note.id)).filter(Boolean));
  for (const element of highlighted) {
    if (!current.has(element)) element.classList.remove('active-note');
  }
  for (const element of current) {
    if (!highlighted.has(element)) element.classList.add('active-note');
  }
  const focusElement = followPlayback && focus && document.getElementById(focus.id);
  if (focusElement && !highlighted.has(focusElement)) {
    const note = focusElement.getBoundingClientRect();
    const viewport = sheet.getBoundingClientRect();
    if (note.top < viewport.top || note.bottom > viewport.bottom) {
      focusElement.scrollIntoView({ block: 'center', inline: 'nearest' });
    }
  }
  highlighted = current;
}

window.HarmoniaScore = { append, load, progress };
notify('ready');
