// Working copies of four things from the app: the Path grid, the Repair
// ledger, the qibla compass, and (for the privacy section) a count of the
// requests this page itself has made. None of them stores anything.

import { PRAYERS, NAMES, DAY, clock, shortDate, weekdayDate, compassWords } from './day.js';
import { ornamentSvg } from './glyphs.js';

const $ = (sel, root = document) => root.querySelector(sel);
const reduceMotion = () => matchMedia('(prefers-reduced-motion: reduce)').matches;

// ── Path: a month as a grid of dots ─────────────────────────────────────
const STATUS = {
  ontime:  { key: 'On time',       row: 'On time' },
  jamaah:  { key: 'In jamāʿah',    row: 'On time, in jamāʿah' },
  delayed: { key: 'Delayed',       row: 'Delayed' },
  missed:  { key: 'Missed',        row: 'Missed' },
  qada:    { key: 'Qaḍā',          row: 'Made up later' },
  none:    { key: 'No record',     row: 'No record' },
  pending: { key: null,            row: 'Not recorded yet' },
  later:   { key: null,            row: 'Later today' },
};
const KEY_ORDER = ['ontime', 'jamaah', 'delayed', 'qada', 'missed', 'none'];
const DAYS = 30;

export class PathSpecimen {
  constructor(root) {
    this.root = root;
    this.selected = DAYS - 1;
    this.sample = null;
    root.innerHTML = `
      <div class="path-grid">
        <div class="path-rows" aria-hidden="true">${PRAYERS.map(p => `<span>${NAMES[p][0]}</span>`).join('')}</div>
        <div class="path-cols" role="group" aria-label="The last thirty days. Each column is a day."></div>
      </div>
      <div class="path-axis" aria-hidden="true"><span data-first></span><span>Tap a day</span><span>Today</span></div>
      <p class="path-total" aria-live="polite"></p>
      <dl class="path-key"></dl>
      <div class="path-day">
        <h3 class="path-day-title"></h3>
        <ul class="path-day-rows"></ul>
      </div>`;
    this.cols = $('.path-cols', root);
    this.cols.addEventListener('click', e => {
      const b = e.target.closest('.path-col');
      if (b) { this.selected = Number(b.dataset.i); this.paint(); }
    });
    this.cols.addEventListener('keydown', e => {
      const step = e.key === 'ArrowRight' ? 1 : e.key === 'ArrowLeft' ? -1 : 0;
      if (!step) return;
      e.preventDefault();
      this.selected = Math.min(DAYS - 1, Math.max(0, this.selected + step));
      this.paint();
      this.cols.children[this.selected].focus();
    });
  }

  /** `today` is a list of five statuses for the current day, from the card in the hero. */
  update(day, today) {
    if (!this.sample || this.sampleFor !== day.start) {
      this.sample = sampleMonth(day);
      this.sampleFor = day.start;
    }
    this.day = day;
    this.today = today;
    this.paint();
  }

  paint() {
    const { day, sample, today } = this;
    const tz = day.city.tz;
    const columns = [...sample, today];
    const counts = Object.fromEntries(KEY_ORDER.map(k => [k, 0]));
    let total = 0, recorded = 0;
    for (const col of columns) for (const s of col) {
      if (s === 'later') continue;
      total++;
      if (s === 'pending') { counts.none++; continue; }
      counts[s]++;
      if (s !== 'none') recorded++;
    }

    if (this.cols.children.length !== DAYS) {
      this.cols.innerHTML = columns.map((_, i) => `<button type="button" class="path-col" data-i="${i}">${'<i class="dot"></i>'.repeat(5)}</button>`).join('');
    }
    columns.forEach((col, i) => {
      const b = this.cols.children[i];
      const ms = day.start - (DAYS - 1 - i) * DAY + DAY / 2;
      const done = col.filter(s => !['none', 'pending', 'later'].includes(s)).length;
      b.setAttribute('aria-pressed', i === this.selected);
      b.setAttribute('aria-label', `${i === DAYS - 1 ? 'Today, ' : ''}${weekdayDate(tz, ms)}: ${done} of 5 recorded`);
      b.tabIndex = i === this.selected ? 0 : -1;
      col.forEach((s, j) => { b.children[j].className = `dot dot-${s}`; });
    });

    $('[data-first]', this.root).textContent = shortDate(tz, day.start - (DAYS - 1) * DAY + DAY / 2);
    $('.path-total', this.root).textContent = `${recorded} of ${total} prayers recorded`;
    $('.path-key', this.root).innerHTML = KEY_ORDER.map(k =>
      `<div><dt><i class="dot dot-${k}"></i>${STATUS[k].key}</dt><dd>${counts[k]}</dd></div>`).join('');

    const i = this.selected;
    const ms = day.start - (DAYS - 1 - i) * DAY + DAY / 2;
    $('.path-day-title', this.root).textContent = (i === DAYS - 1 ? 'Today, ' : '') + weekdayDate(tz, ms);
    $('.path-day-rows', this.root).innerHTML = columns[i].map((s, j) =>
      `<li><i class="dot dot-${s}"></i><span>${NAMES[PRAYERS[j]][0]}</span><span class="path-day-status">${STATUS[s].row}</span></li>`).join('');
  }
}

// Twenty-nine invented days, the same on every visit. Friday's Dhuhr is in jamāʿah.
function sampleMonth(day) {
  let seed = 622;
  const rnd = () => ((seed = (seed * 16807) % 2147483647) - 1) / 2147483646;
  const out = [];
  for (let i = 0; i < DAYS - 1; i++) {
    const ms = day.start - (DAYS - 1 - i) * DAY + DAY / 2;
    const weekday = new Intl.DateTimeFormat('en-US', { timeZone: day.city.tz, weekday: 'short' }).format(ms);
    out.push(PRAYERS.map(p => {
      const r = rnd();
      if (weekday === 'Fri' && p === 'dhuhr') return 'jamaah';
      if (r < 0.74) return 'ontime';
      if (r < 0.82) return 'jamaah';
      if (r < 0.93) return 'delayed';
      if (r < 0.965) return 'none';
      if (r < 0.985) return 'qada';
      return 'missed';
    }));
  }
  return out;
}

// ── Repair: a ledger of what is owed ────────────────────────────────────
export class RepairSpecimen {
  constructor(root) {
    this.root = root;
    this.owed = { Isha: 24, Fasts: 18 };
    this.start = 42;
    root.innerHTML = `
      <p class="ui-label">Repair</p>
      <h3 class="repair-title">The thread grows.</h3>
      <div class="thread" aria-hidden="true"><span class="thread-done"></span><span class="thread-end">${ornamentSvg('maghrib', 22, 'outline')}</span></div>
      <p class="repair-counts ui-label" aria-live="polite"></p>
      <p class="repair-note">When you’re ready, one makeup can sit beside one daily prayer.</p>
      <ul class="repair-rows">
        ${Object.keys(this.owed).map(k => `<li><span>${k}</span><button type="button" class="btn btn-line" data-k="${k}">+1 made up</button></li>`).join('')}
      </ul>`;
    root.addEventListener('click', e => {
      const b = e.target.closest('button[data-k]');
      if (!b || this.owed[b.dataset.k] === 0) return;
      this.owed[b.dataset.k]--;
      this.paint();
    });
    this.paint();
  }
  paint() {
    const left = this.owed.Isha + this.owed.Fasts;
    const made = this.start - left;
    $('.repair-counts', this.root).innerHTML = `<span>Isha · ${this.owed.Isha}</span><span>Fasts · ${this.owed.Fasts}</span>${made ? `<span class="repair-made">Made up · ${made}</span>` : ''}`;
    $('.thread-done', this.root).style.width = `${(made / this.start) * 100}%`;
    for (const b of this.root.querySelectorAll('button[data-k]')) b.disabled = this.owed[b.dataset.k] === 0;
  }
}

// ── Qibla: a compass that holds north and marks the direction on its rim ─
export class QiblaSpecimen {
  constructor(root) {
    this.root = root;
    this.heading = 0;
    this.bearing = 0;
    this.near = false;
    let ticks = '';
    for (let d = 0; d < 360; d += 3) {
      const major = d % 30 === 0, mid = d % 15 === 0;
      const r0 = major ? 131 : mid ? 136 : 140;
      ticks += `<line class="${major ? 'q-tick q-major' : 'q-tick'}" x1="0" y1="${-r0}" x2="0" y2="-148" transform="rotate(${d})"/>`;
    }
    const letters = [['N', 0], ['E', 90], ['S', 180], ['W', 270]]
      .map(([l, d]) => `<text class="q-letter" transform="rotate(${d}) translate(0 -112) rotate(${-d})" dy="4">${l}</text>`).join('');
    root.innerHTML = `
      <div class="qibla-dial" role="slider" tabindex="0" aria-label="The way you are facing" aria-valuemin="0" aria-valuemax="359">
        <svg viewBox="-180 -180 360 360" aria-hidden="true">
          <defs><radialGradient id="q-glow"><stop offset="0" stop-color="var(--glow)" stop-opacity=".55"/><stop offset="1" stop-color="var(--glow)" stop-opacity="0"/></radialGradient></defs>
          <path class="q-index" d="M0 -160 L-5 -171 L5 -171 Z"/>
          <g class="q-ring">
            <circle class="q-rim" r="150"/><circle class="q-rim q-inner" r="126"/>
            ${ticks}${letters}
            <g class="q-mark"><circle r="26" cy="-150" fill="url(#q-glow)"/><path d="M0 -163 L7 -150 L0 -141 L-7 -150 Z"/></g>
          </g>
          <path class="q-rose" d="M0 -19L5.4 -13 13.4 -13.4 13 -5.4 19 0 13 5.4 13.4 13.4 5.4 13 0 19 -5.4 13 -13.4 13.4 -13 5.4 -19 0 -13 -5.4 -13.4 -13.4 -5.4 -13Z"/>
        </svg>
      </div>
      <p class="qibla-read ui-label"></p>
      <p class="qibla-dist ui-label"></p>
      <p class="qibla-state" aria-live="polite"></p>
      <button type="button" class="btn btn-line qibla-turn">Turn to face it</button>`;
    this.dial = $('.qibla-dial', root);
    this.ring = $('.q-ring', root);
    this.mark = $('.q-mark', root);

    let last = null;
    const angleOf = e => {
      const box = this.dial.getBoundingClientRect();
      return Math.atan2(e.clientY - (box.top + box.height / 2), e.clientX - (box.left + box.width / 2)) * 180 / Math.PI;
    };
    this.dial.addEventListener('pointerdown', e => { last = angleOf(e); this.dial.setPointerCapture(e.pointerId); this.cancelSpin(); });
    this.dial.addEventListener('pointermove', e => {
      if (last === null) return;
      const a = angleOf(e);
      let delta = a - last;
      if (delta > 180) delta -= 360; else if (delta < -180) delta += 360;
      last = a;
      this.setHeading(this.heading - delta);
    });
    const stop = () => { last = null; };
    this.dial.addEventListener('pointerup', stop);
    this.dial.addEventListener('pointercancel', stop);
    this.dial.addEventListener('keydown', e => {
      const step = { ArrowRight: 3, ArrowUp: 3, ArrowLeft: -3, ArrowDown: -3, PageUp: 15, PageDown: -15 }[e.key];
      if (e.key === 'Home') { e.preventDefault(); this.setHeading(0); return; }
      if (!step) return;
      e.preventDefault();
      this.cancelSpin();
      this.setHeading(this.heading + step);
    });
    $('.qibla-turn', root).addEventListener('click', () => this.spinTo(this.bearing));
  }

  update(day) {
    this.bearing = day.qibla;
    this.mark.setAttribute('transform', `rotate(${this.bearing.toFixed(2)})`);
    const km = Math.round(day.distanceKm).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ' ');
    const here = day.city.custom ? 'here' : `in ${day.city.name}`;
    // In Makkah itself there is no bearing worth drawing: the Kaaba is in front of you.
    this.near = day.distanceKm < 5;
    this.mark.style.display = this.near ? 'none' : '';
    $('.qibla-read', this.root).textContent = this.near
      ? 'The Kaaba is here'
      : `Qibla is ${Math.round(this.bearing)}° ${compassWords(this.bearing)} of true north ${here}`;
    $('.qibla-dist', this.root).textContent = this.near ? 'Less than 5 km away' : `${km} km to the Kaaba`;
    this.setHeading(this.heading);
  }

  setHeading(h) {
    this.heading = ((h % 360) + 360) % 360;
    this.ring.setAttribute('transform', `rotate(${(-this.heading).toFixed(2)})`);
    let off = this.bearing - this.heading;
    off = ((off + 540) % 360) - 180;
    const facing = !this.near && Math.abs(off) <= 2;
    this.root.classList.toggle('is-facing', facing);
    const words = `${Math.round(this.heading) % 360}° ${compassWords(this.heading)}`;
    const state = this.near ? `Facing ${words}.`
      : facing ? 'Facing the qibla.'
      : `Facing ${words}. The qibla is ${Math.abs(Math.round(off))}° to your ${off > 0 ? 'right' : 'left'}.`;
    $('.qibla-state', this.root).textContent = state;
    this.dial.setAttribute('aria-valuenow', Math.round(this.heading) % 360);
    this.dial.setAttribute('aria-valuetext', state);
    $('.qibla-turn', this.root).hidden = facing || this.near;
  }

  cancelSpin() { if (this.raf) cancelAnimationFrame(this.raf); this.raf = 0; }
  spinTo(target) {
    this.cancelSpin();
    if (reduceMotion()) { this.setHeading(target); return; }
    const from = this.heading;
    let delta = ((target - from + 540) % 360) - 180;
    const t0 = performance.now(), dur = 900 + Math.abs(delta) * 4;
    const frame = now => {
      const t = Math.min(1, (now - t0) / dur);
      const e = 1 - (1 - t) ** 3;
      this.setHeading(from + delta * e);
      this.raf = t < 1 ? requestAnimationFrame(frame) : 0;
    };
    this.raf = requestAnimationFrame(frame);
  }
}

// ── The page's own network ledger ───────────────────────────────────────
export function watchRequests(root) {
  const own = location.host;
  const paint = () => {
    const entries = performance.getEntriesByType('resource');
    const hosts = new Map();
    for (const e of entries) {
      let host = own;
      try { host = new URL(e.name, location.href).host || own; } catch { /* a data: or blob: URL made here */ }
      if (/^(data|blob|about):/.test(e.name)) host = own;
      hosts.set(host, (hosts.get(host) || 0) + 1);
    }
    const total = entries.length + 1; // and the page itself
    const others = [...hosts.keys()].filter(h => h !== own);
    const mine = total - others.reduce((n, h) => n + hosts.get(h), 0);
    root.innerHTML = others.length === 0
      ? `<strong>${total} requests so far, all ${total} to ${escapeHtml(own)}.</strong> None to anyone else. Your browser counted them; the page only read the count back.`
      : `<strong>${total} requests so far: ${mine} to ${escapeHtml(own)}</strong> and ${total - mine} to ${others.map(escapeHtml).join(', ')}. That second number should be zero. If it is not, something between you and this page added it.`;
  };
  paint();
  try { new PerformanceObserver(paint).observe({ type: 'resource', buffered: false }); } catch { /* the first count stands */ }
}

const escapeHtml = s => s.replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

// ── The closing line: today's five, wherever the visitor is ─────────────
export function paintTimes(root, day, cycle, nextUp) {
  const tz = day.city.tz;
  root.innerHTML = PRAYERS.map(p =>
    `<li${nextUp.prayer === p ? ' class="is-next"' : ''}>${ornamentSvg(p, 26, nextUp.prayer === p ? 'filled' : 'outline')}<span class="times-name">${NAMES[p][0]}</span><span class="times-at">${clock(tz, cycle[p])}</span></li>`).join('');
}
