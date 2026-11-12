'use strict';

const sheet = document.getElementById('sheet');
const state = document.getElementById('state');
const pages = document.getElementById('pages');
const previous = document.getElementById('previous');
const next = document.getElementById('next');
const pageNumber = document.getElementById('pageNumber');
const buffers = { score: [], timeline: [] };
let toolkit;
let page = 0;
let pageCount = 0;
let notes = [];
let latestEnd = [];
let highlighted = [];
let followedPage = 0;
let position = -1;

function notify(message) {
  if (window.webkit?.messageHandlers?.scoreStatus) {
    window.webkit.messageHandlers.scoreStatus.postMessage(message);
  } else {
    window.ScoreStatus?.postMessage(message);
  }
}

function showError() {
  state.hidden = false;
  state.textContent = 'Không thể hiển thị khuông nhạc.';
  notify('error');
}

function init() {
  toolkit = new verovio.toolkit();
  toolkit.setOptions({
    expandNever: true,
    breaks: 'auto',
    pageWidth: 1200,
    pageHeight: 1600,
    pageMarginLeft: 32,
    pageMarginRight: 32,
    adjustPageHeight: true,
    svgViewBox: true,
  });
  notify('ready');
}

function render(target) {
  if (target < 1 || target > pageCount || target === page) return;
  sheet.innerHTML = toolkit.renderToSVG(target);
  page = target;
  pageNumber.textContent = target + ' / ' + pageCount;
  previous.disabled = page === 1;
  next.disabled = page === pageCount;
  highlighted = [];
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

function load() {
  try {
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
    if (!toolkit.loadData(new XMLSerializer().serializeToString(xml))) {
      throw new Error('Verovio rejected MusicXML');
    }

    notes = JSON.parse(read('timeline')).flatMap(([locator, start, end]) => {
      const id = ids.get(locator);
      if (!id) return [];
      return [{ id, start, end }];
    }).sort((a, b) => a.start - b.start);
    let maxEnd = 0;
    latestEnd = notes.map(note => (maxEnd = Math.max(maxEnd, note.end)));
    pageCount = toolkit.getPageCount();
    if (pageCount < 1) throw new Error('No engraving pages');
    render(1);
    state.hidden = true;
    pages.hidden = pageCount === 1;
    notify('loaded');
  } catch (_) {
    showError();
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
  const first = active[0];
  const target = first && (document.getElementById(first.id) ? page : toolkit.getPageWithElement(first.id));
  if (target && target !== followedPage) render(target);
  followedPage = target;
  for (const element of highlighted) element.classList.remove('active-note');
  highlighted = active.map(note => document.getElementById(note.id)).filter(Boolean);
  for (const element of highlighted) element.classList.add('active-note');
}

window.HarmoniaScore = { append, load, progress };
if (typeof verovio === 'undefined') showError();
else if (verovio.module.calledRun) init();
else {
  verovio.module.onRuntimeInitialized = init;
  verovio.module.onAbort = showError;
  window.setTimeout(() => { if (!toolkit) showError(); }, 15000);
}
