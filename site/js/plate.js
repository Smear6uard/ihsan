// The plate: the day drawn as an arch over a horizon, after the app's
// PlateGeometry. Five prayers sit on the arc at their times; the sun and
// moon ride a wheel beneath it; the stars turn behind.

import { PRAYERS, NAMES, clock, shownCycle, momentAt, sunAngle, instantForSunAngle, moonElongation, siderealAngle, clamp01 } from './day.js';
import { ornament, moonLit } from './glyphs.js';

const NS = 'http://www.w3.org/2000/svg';
const INSET = 0.09;
const el = (name, attrs = {}, parent) => {
  const node = document.createElementNS(NS, name);
  for (const [k, v] of Object.entries(attrs)) node.setAttribute(k, v);
  if (parent) parent.appendChild(node);
  return node;
};
const f = n => n.toFixed(1);

export class Plate {
  /**
   * @param {HTMLElement} sky    the box whose bottom edge is the horizon
   * @param {HTMLCanvasElement} canvas  the star field, covering everything above the horizon
   * @param {(ms:number)=>void} onDrag  called while the sun or moon is dragged
   */
  constructor(sky, canvas, onDrag) {
    this.sky = sky;
    this.canvas = canvas;
    this.onDrag = onDrag;
    this.day = null;
    this.ms = 0;
    this.logs = new Map();
    this.starlight = 1;
    this.g = null;
    this.stars = null;
    this.build();
    new ResizeObserver(() => { this.layout(); this.render(); }).observe(sky);
    new ResizeObserver(() => { this.sizeCanvas(); this.drawStars(); }).observe(canvas.parentElement);
  }

  build() {
    const svg = this.svg = el('svg', { class: 'plate-svg', role: 'img', 'aria-labelledby': 'plate-title' });
    this.title = el('title', { id: 'plate-title' }, svg);
    const defs = el('defs', {}, svg);
    defs.innerHTML = `
      <radialGradient id="g-halo"><stop offset="0" stop-color="var(--glow)" stop-opacity=".72"/><stop offset=".4" stop-color="var(--glow)" stop-opacity=".3"/><stop offset=".7" stop-color="var(--glow)" stop-opacity=".08"/><stop offset="1" stop-color="var(--glow)" stop-opacity="0"/></radialGradient>
      <radialGradient id="g-sun"><stop offset="0" stop-color="var(--glow)" stop-opacity=".95"/><stop offset=".2" stop-color="var(--glow)" stop-opacity=".78"/><stop offset=".42" stop-color="var(--glow)" stop-opacity=".3"/><stop offset=".72" stop-color="var(--glow)" stop-opacity=".08"/><stop offset="1" stop-color="var(--glow)" stop-opacity="0"/></radialGradient>
      <radialGradient id="g-moon"><stop offset="0" stop-color="#F4ECDF" stop-opacity=".34"/><stop offset=".5" stop-color="#F4ECDF" stop-opacity=".08"/><stop offset="1" stop-color="#F4ECDF" stop-opacity="0"/></radialGradient>
      <mask id="m-knock" maskUnits="userSpaceOnUse"><rect id="m-rect" fill="#fff"/><g id="m-holes" fill="#000"></g></mask>`;
    this.maskRect = defs.querySelector('#m-rect');
    this.maskHoles = defs.querySelector('#m-holes');

    this.road = el('path', { class: 'plate-road' }, svg);
    const arcs = el('g', { mask: 'url(#m-knock)' }, svg);
    this.track = el('path', { class: 'plate-track', pathLength: 1 }, arcs);
    this.done = el('path', { class: 'plate-done' }, arcs);
    this.tick = el('path', { class: 'plate-tick' }, svg);
    this.sunriseLabel = el('text', { class: 'plate-note' }, svg);

    this.moon = el('g', { class: 'plate-moon', tabindex: -1 }, svg);
    this.moon.innerHTML = `<circle class="moon-halo" r="60" fill="url(#g-moon)"/><circle class="moon-disc"/><path class="moon-lit"/><circle class="orb-hit" r="34"/>`;
    this.sun = el('g', { class: 'plate-sun' }, svg);
    this.sun.innerHTML = `<circle class="sun-halo" fill="url(#g-sun)"/><circle class="sun-disc"/><circle class="orb-hit" r="40"/>`;

    this.markers = {};
    PRAYERS.forEach((p, i) => {
      const g = el('g', { class: 'marker', 'data-prayer': p, style: `--i:${i}` }, svg);
      const halo = el('circle', { class: 'marker-halo', fill: 'url(#g-halo)' }, g);
      const glyph = el('g', { class: 'marker-glyph' }, g);
      const name = el('text', { class: 'marker-name' }, g);
      const time = el('text', { class: 'marker-time' }, g);
      name.textContent = NAMES[p][0];
      this.markers[p] = { g, halo, glyph, name, time };
    });
    this.sky.appendChild(svg);

    for (const [orb, isMoon] of [[this.sun, false], [this.moon, true]]) this.makeDraggable(orb, isMoon);
  }

  makeDraggable(orb, isMoon) {
    let dragging = false;
    const move = e => {
      if (!dragging || !this.g || !this.day) return;
      const box = this.svg.getBoundingClientRect();
      const road = isMoon ? this.g.moon : this.g.sun;
      const x = e.clientX - box.left, y = e.clientY - box.top;
      let angle = Math.atan2((this.g.horizon - y) / road.b, (this.g.cx - x) / road.a);
      if (isMoon) angle += moonElongation(this.ms);
      this.onDrag(instantForSunAngle(this.day, angle));
    };
    orb.addEventListener('pointerdown', e => {
      dragging = true;
      orb.setPointerCapture(e.pointerId);
      this.sky.classList.add('is-dragging');
      e.preventDefault();
    });
    orb.addEventListener('pointermove', move);
    const stop = () => { dragging = false; this.sky.classList.remove('is-dragging'); };
    orb.addEventListener('pointerup', stop);
    orb.addEventListener('pointercancel', stop);
  }

  // ── Geometry ──────────────────────────────────────────────────────────
  layout() {
    const w = this.sky.clientWidth, h = this.sky.clientHeight;
    if (!w || !h) return;
    const compact = w < 700;
    const mc = compact ? 24 : 34;
    const top = mc + (compact ? 6 : 12);
    const rise = Math.max(140, h - top);
    const semi = Math.max(110, Math.min(w / 2 - mc - (compact ? 10 : 40), rise * 1.5));
    const sun = { a: semi - (compact ? 42 : 86), b: rise - (compact ? 74 : 112) };
    this.g = {
      w, h, compact, cx: w / 2, horizon: h, rise, semi, sun,
      moon: { a: sun.a * 0.9, b: sun.b * 0.88 },
      glyph: compact ? 32 : 44,
      sunR: compact ? 15 : 22,
      moonR: compact ? 11 : 16,
    };
    this.svg.setAttribute('viewBox', `0 0 ${w} ${h}`);
    this.svg.setAttribute('width', w);
    this.svg.setAttribute('height', h);
    this.maskRect.setAttribute('width', w);
    this.maskRect.setAttribute('height', h);
    // The headline is sized from the arch it sits inside.
    const frame = this.sky.parentElement.style;
    frame.setProperty('--rise', `${rise}px`);
    frame.setProperty('--semi', `${semi}px`);

    const g = this.g;
    this.road.setAttribute('d', `M${f(g.cx - sun.a)} ${f(g.horizon)}A${f(sun.a)} ${f(sun.b)} 0 0 1 ${f(g.cx + sun.a)} ${f(g.horizon)}`);
    this.sun.querySelector('.sun-halo').setAttribute('r', g.sunR * 4.4);
    this.sun.querySelector('.sun-disc').setAttribute('r', g.sunR);
    this.moon.querySelector('.moon-disc').setAttribute('r', g.moonR);
    for (const p of PRAYERS) {
      const m = this.markers[p];
      m.glyph.innerHTML = ornament(p, g.glyph);
      m.halo.setAttribute('r', g.glyph * 1.45);
    }
    this.cycleKey = null; // marker positions depend on the box
  }

  arcPoint(u) {
    const { cx, horizon, semi, rise } = this.g;
    const theta = Math.PI * (1 - u);
    return [cx + semi * Math.cos(theta), horizon - rise * Math.sin(theta)];
  }
  uFor(cycle, ms) {
    return INSET + clamp01((ms - cycle.fajr) / Math.max(60000, cycle.isha - cycle.fajr)) * (1 - 2 * INSET);
  }

  placeMarkers(cycle) {
    const g = this.g, tz = this.day.city.tz;
    const pts = PRAYERS.map(p => this.arcPoint(this.uFor(cycle, cycle[p])));
    const lineH = g.compact ? 13 : 16;
    const below = g.glyph / 2 + (g.compact ? 15 : 20);
    let holes = '';
    PRAYERS.forEach((p, i) => {
      const [x, y] = pts[i];
      const m = this.markers[p];
      m.g.setAttribute('transform', `translate(${f(x)} ${f(y)})`);
      m.time.textContent = clock(tz, cycle[p]);
      // A label normally sits beneath its ornament. When the next ornament
      // would land on it, the label moves inside the arch instead.
      const next = pts[i + 1];
      const crowded = next && Math.abs(next[0] - x) < 52 && next[1] - y < g.glyph + lineH * 2 + 16;
      if (crowded) {
        const dx = -(g.glyph / 2 + 12);
        m.name.setAttribute('x', dx); m.name.setAttribute('y', -2); m.name.setAttribute('text-anchor', 'end');
        m.time.setAttribute('x', dx); m.time.setAttribute('y', lineH - 1); m.time.setAttribute('text-anchor', 'end');
      } else {
        m.name.setAttribute('x', 0); m.name.setAttribute('y', below); m.name.setAttribute('text-anchor', 'middle');
        m.time.setAttribute('x', 0); m.time.setAttribute('y', below + lineH); m.time.setAttribute('text-anchor', 'middle');
      }
      holes += `<circle cx="${f(x)}" cy="${f(y)}" r="${f(g.glyph / 2 + 7)}"/>`;
      // The arc is engraved around its inscriptions, never through them.
      for (const t of [m.name, m.time]) {
        const b = t.getBBox();
        if (b.width) holes += `<rect x="${f(x + b.x - 5)}" y="${f(y + b.y - 1)}" width="${f(b.width + 10)}" height="${f(b.height + 2)}" rx="3"/>`;
      }
    });

    const [x0, y0] = pts[0], [x1, y1] = pts[4];
    this.track.setAttribute('d', `M${f(x0)} ${f(y0)}A${f(g.semi)} ${f(g.rise)} 0 0 1 ${f(x1)} ${f(y1)}`);

    // Sunrise: a tick on the arc at its time, and a note beside it.
    const uSun = this.uFor(cycle, cycle.sunrise);
    const [sx, sy] = this.arcPoint(uSun);
    const theta = Math.PI * (1 - uSun);
    const nx = Math.cos(theta) * g.rise, ny = -Math.sin(theta) * g.semi; // outward normal of the ellipse
    const nl = Math.hypot(nx, ny) || 1;
    const tx = (nx / nl) * 6, ty = (ny / nl) * 6;
    this.tick.setAttribute('d', `M${f(sx - tx)} ${f(sy - ty)}L${f(sx + tx)} ${f(sy + ty)}`);
    this.sunriseLabel.textContent = `Sunrise ${clock(tz, cycle.sunrise)}`;
    this.sunriseLabel.setAttribute('x', f(sx + 16));
    this.sunriseLabel.setAttribute('y', f(sy + 4));
    this.maskHoles.innerHTML = holes;
  }

  // ── Drawing a moment ──────────────────────────────────────────────────
  update(day, ms, logs, starlight = 1) {
    if (day !== this.day) this.cycleKey = null;
    this.day = day; this.ms = ms; this.logs = logs; this.starlight = starlight;
    if (!this.g) this.layout();
    this.render();
  }

  render() {
    const { day, ms, g } = this;
    if (!day || !g) return;
    const cycle = shownCycle(day, ms);
    if (cycle.key !== this.cycleKey) { this.placeMarkers(cycle); this.cycleKey = cycle.key; }

    const moment = momentAt(day, ms);
    for (const p of PRAYERS) {
      const m = this.markers[p];
      const isNow = moment.cycle === cycle && moment.now === p;
      const log = this.logs.get(`${cycle.key}:${p}`);
      const recorded = Boolean(log) && log.at <= ms;
      m.g.classList.toggle('is-now', isNow);
      m.g.classList.toggle('is-filled', isNow || recorded);
    }

    // The gold line is the part of the day already walked.
    const u = this.uFor(cycle, ms);
    if (ms <= cycle.fajr) {
      this.done.setAttribute('d', '');
    } else {
      const [x0, y0] = this.arcPoint(INSET), [x1, y1] = this.arcPoint(u);
      this.done.setAttribute('d', `M${f(x0)} ${f(y0)}A${f(g.semi)} ${f(g.rise)} 0 0 1 ${f(x1)} ${f(y1)}`);
    }

    // Sun and moon on their wheel.
    const phi = sunAngle(day, ms);
    const sx = g.cx - g.sun.a * Math.cos(phi), sy = g.horizon - g.sun.b * Math.sin(phi);
    this.sun.setAttribute('transform', `translate(${f(sx)} ${f(sy)})`);
    this.sun.style.opacity = Math.sin(phi) > -0.12 ? 1 : 0;

    const e = moonElongation(ms);
    const mphi = phi - e;
    const mx = g.cx - g.moon.a * Math.cos(mphi), my = g.horizon - g.moon.b * Math.sin(mphi);
    this.moon.setAttribute('transform', `translate(${f(mx)} ${f(my)})`);
    const lit = moonLit(g.moonR, e, day.city.lat < 0);
    const litPath = this.moon.querySelector('.moon-lit');
    litPath.setAttribute('d', lit.d);
    litPath.setAttribute('transform', lit.flip ? 'scale(-1 1)' : '');
    const up = Math.sin(mphi);
    // Within a day or so of the new moon there is nothing to see, here as in the sky.
    const lit01 = (1 - Math.cos(e)) / 2;
    const seen = Math.min(1, Math.max(0, (lit01 - 0.012) / 0.04));
    this.moon.style.opacity = up > -0.08 ? (this.starlight ** 0.8 * seen).toFixed(2) : 0;
    this.moon.querySelector('.moon-halo').style.opacity = (0.25 + 0.75 * lit01).toFixed(2);
    this.moon.style.pointerEvents = up > 0 ? '' : 'none';

    // The horizon warms where the sun is close to it.
    const near = Math.max(0, 1 - Math.abs(Math.sin(phi)) / 0.42) ** 1.4;
    this.sky.style.setProperty('--sun-x', `${f(sx)}px`);
    this.sky.style.setProperty('--horizon-glow', near.toFixed(3));

    const tz = day.city.tz;
    this.title.textContent = `Today's five prayers in ${day.city.name}: ` +
      PRAYERS.map(p => `${NAMES[p][0]} ${clock(tz, cycle[p])}`).join(', ') + '.';

    this.drawStars();
  }

  // ── Stars ─────────────────────────────────────────────────────────────
  sizeCanvas() {
    const c = this.canvas, box = c.parentElement;
    const w = box.clientWidth, h = box.clientHeight;
    if (!w || !h) return;
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    c.width = Math.round(w * dpr); c.height = Math.round(h * dpr);
    c.style.width = `${w}px`; c.style.height = `${h}px`;
    this.cw = w; this.ch = h; this.dpr = dpr;

    // The same sky on every visit: a seeded field, laid out around the pivot
    // the stars turn on, far below the horizon.
    let seed = 1448;
    const rnd = () => ((seed = (seed * 16807) % 2147483647) - 1) / 2147483646;
    const pivotY = h + Math.max(w, h) * 0.55;
    const R = Math.hypot(w / 2, pivotY) + 20;
    const n = Math.round((Math.PI * R * R) / 9000);
    const stars = [];
    for (let i = 0; i < n; i++) {
      const bright = rnd() > 0.9;
      stars.push({ r: R * Math.sqrt(rnd()), a: rnd() * Math.PI * 2, size: bright ? 1.1 + rnd() * 0.5 : 0.45 + rnd() * 0.55, alpha: bright ? 0.7 + rnd() * 0.3 : 0.2 + rnd() * 0.5 });
    }
    this.stars = { list: stars, pivotY };
  }

  drawStars() {
    if (!this.stars) this.sizeCanvas();
    if (!this.stars) return;
    const ctx = this.canvas.getContext('2d');
    const { cw: w, ch: h, dpr } = this;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, w, h);
    const visible = this.starlight ?? 1;
    if (visible < 0.02) return;
    const turn = siderealAngle(this.ms);
    const { list, pivotY } = this.stars;
    ctx.fillStyle = '#ECEEF5';
    for (const s of list) {
      const a = s.a + turn;
      const x = w / 2 - s.r * Math.cos(a), y = pivotY - s.r * Math.sin(a);
      if (y > h || y < -2 || x < -2 || x > w + 2) continue;
      // Stars thin out toward the horizon, as they do through thicker air.
      const fade = Math.min(1, (h - y) / (h * 0.28));
      ctx.globalAlpha = s.alpha * visible * fade;
      ctx.beginPath();
      ctx.arc(x, y, s.size, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.globalAlpha = 1;
  }
}
